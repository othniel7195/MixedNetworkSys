//
//  MixedNetworkProvider.swift
//  MixedNetworkSys
//
//  Created by jimmy on 08/26/2021.
//

import Foundation
import Alamofire

public final class MixedNetworkProvider {
    ///降级策略
    public enum FallbackStrategy {
        /// Normal -> HTTPDNS->CDN
        case `default`
        
        /// HTTPDNS -> Normal/CDN
        case httpDNSFirst
        // CDN -> Normal
        case CDNFirst
        
    }
    
    private let fallbackStrategy: FallbackStrategy
    private let normalStage: NetworkProvider
    private let dnsStage: NetworkProvider
    private let cdnStage: NetworkProvider
    private let cdnHostOfOriginalHost: ((String) -> String?)?
    
    ///plugins: 插件列表。例如 Log 插件、权限验证插件、网络活动指示器插件
    ///hosts:  支持的域名列表
    ///callbackQueue: 回调队列。默认为 main
    ///fallbackStrategy: 降级策略。默认为 default
    ///cdnHostOfOriginalHost: 原始 Host 到 CDN Host 的映射
    public init(configuration: NetworkURLSessionConfiguration,
                plugins: [PluginType] = [],
                hosts: [String],
                callbackQueue: DispatchQueue = .main,
                fallbackStrategy: FallbackStrategy = .default,
                cdnHostOfOriginalHost: ((String) -> String?)? = nil) {
        
        self.fallbackStrategy = fallbackStrategy
        self.cdnHostOfOriginalHost = cdnHostOfOriginalHost
        
        self.normalStage = .init(configuration: .init(useHTTPDNS: false), plugins: plugins, hosts: hosts, callbackQueue: callbackQueue)
        
        self.dnsStage = .init(configuration: .init(useHTTPDNS: true), plugins: plugins, hosts: hosts, callbackQueue: callbackQueue)
        
        self.cdnStage = .init(configuration: .init(useHTTPDNS: true), plugins: plugins, hosts: hosts, callbackQueue: callbackQueue)
        
    }
}


extension MixedNetworkProvider {
    public func request(_ dataTarget: DataTargetType,
                        callbackQueue: DispatchQueue? = nil,
                        completion: @escaping Completion) -> NetworkDataTask? {
        let task = TaskToken()
        switch fallbackStrategy {
        case .default:
            normalRequest(dataTarget, callbackQueue: callbackQueue, task: task) { [weak self] result in
                switch result {
                case .success(let response):
                    completion(.success(response))
                case .failure(let error):
                    self?.dnsRequest(dataTarget, callbackQueue: callbackQueue, error: error, task: task) { result in
                        switch result {
                        case .success(let response):
                            completion(.success(response))
                        case .failure(let error):
                            self?.cdnRequest(dataTarget,
                                             callbackQueue: callbackQueue,
                                             error: error,
                                             task: task,
                                             completion: completion)
                        }
                    }
                }
            }
        case .httpDNSFirst:
            dnsRequest(dataTarget, callbackQueue: callbackQueue, error: nil, task: task) { [weak self] result in
                switch result {
                case .success(let response):
                    completion(.success(response))
                case .failure(let error):
                    self?.cdnRequest(dataTarget, callbackQueue: callbackQueue, error: error, task: task, completion: { result in
                        switch result {
                        case .success(let response):
                            completion(.success(response))
                        case .failure:
                            self?.normalRequest(dataTarget, callbackQueue: callbackQueue, task: task, completion: completion)
                        }
                    })
                }
            }
        case .CDNFirst:
            cdnRequest(dataTarget, callbackQueue: callbackQueue, task: task) { [weak self] result in
                switch result {
                case .success(let response):
                    completion(.success(response))
                case .failure:
                    self?.normalRequest(dataTarget, callbackQueue: callbackQueue, task: task, completion: completion)
                }
            }
            
        }
        return task
    }
}


///default request
extension MixedNetworkProvider {
    private func  normalRequest(_ dataTarget: DataTargetType,
                                callbackQueue: DispatchQueue?,
                                task: TaskToken,
                                completion: @escaping Completion) {
        if let normalTask = normalStage.request(dataTarget, callbackQueue: callbackQueue, completion: { result in
            switch result {
            case .success(let response):
                completion(.success(response))
            case .failure(let error):
                #if DEBUG
                print("❌ normalStage-error:", error)
                #endif
                completion(.failure(error))
            }
        }) {
            task.restart(with: normalTask)
        } else {
            completion(.failure(NetError.underlying(NSError(domain: "normal task is null", code: -99998, userInfo: nil), nil)))
        }
    }
}


///HTTPDNS request
extension MixedNetworkProvider {
    private func dnsRequest(_ dataTarget: DataTargetType,
                            callbackQueue: DispatchQueue?,
                            error: NetError? = nil ,
                            task: TaskToken,
                            completion: @escaping Completion) {
        guard let host = dataTarget.fullRequestURL.host else {
            completion(.failure(error ?? NetError.underlying(NSError(domain: "未知错误", code: -99999, userInfo: nil), nil)))
            return
        }
        
        HTTPDNS.query(host) { [weak self] result in
            guard let self = self else { return }
            if let result = result {
                #if DEBUG
                print("HTTPDNS:", host, result.ipAddress)
                #endif
                if let dnsTask = self.dnsStage.request(dataTarget, callbackQueue: callbackQueue, completion: { result in
                    switch result {
                    case .success(let response):
                        completion(.success(response))
                    case .failure(let error):
                        #if DEBUG
                        print("❌ dnsStage-error:", error)
                        #endif
                        completion(.failure(error))
                    }
                }){
                    task.restart(with: dnsTask)
                }
            } else {
                completion(.failure(error ?? NetError.underlying(NSError(domain: "dns task is null", code: -99998, userInfo: nil), nil)))
            }
        }
    }
}


///CDN request
extension MixedNetworkProvider {
    
    private func cdnRequest(_ dataTarget: DataTargetType,
                            callbackQueue: DispatchQueue?,
                            error: NetError? = nil ,
                            task: TaskToken,
                            completion: @escaping Completion) {
        guard let cdnBaseURL = self.cdnBaseURL(of: dataTarget.baseURL) else {
            completion(.failure(error ?? NetError.underlying(NSError(domain: "未知错误", code: -99999, userInfo: nil), nil)))
            return
        }
        
        struct Endpoint: DataTargetType {
            var baseURL: URL
            var path: String
            var method: HTTPMethod
            var parameters: [String: Any]?
            var headers: [String: String]?
            var validation: ValidationType
            var priority: Float
            var timeoutInterval: TimeInterval?
        }
        
        let endpoint = Endpoint(baseURL: cdnBaseURL, path: dataTarget.path, method: dataTarget.method, parameters: dataTarget.parameters, headers: dataTarget.headers, validation: dataTarget.validation, priority: dataTarget.priority, timeoutInterval: dataTarget.timeoutInterval)
        if let cdnTask = cdnStage.request(endpoint, callbackQueue: callbackQueue, completion: { result in
            switch result {
            case .success(let response):
                completion(.success(response))
            case .failure(let error):
                #if DEBUG
                print("❌ cdnStage-error:", error)
                #endif
                completion(.failure(error))
            }
        }) {
            task.restart(with: cdnTask)
        } else {
            completion(.failure(NetError.underlying(NSError(domain: "cdn task is null", code: -99998, userInfo: nil), nil)))
        }
        
    }
    
    private func cdnBaseURL(of baseURL: URL) -> URL? {
        guard let host = baseURL.host else { return nil }
        guard let cdnHost = cdnHostOfOriginalHost?(host) else { return nil }
        return baseURL.network_replacingHost(host, with: cdnHost)
    }
}
