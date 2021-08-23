//
//  NetworkProvider2.swift
//  MixedNetworkSys
//
//  Created by jimmy on 2021/8/23.
//

import Foundation
import Alamofire

public typealias Completion = (_ result: Result<Response, NetError>) -> Void

public typealias ProgressBlock = (Progress) -> Void

open class NetworkProvider2 {
    
    public let configuration: NetworkURLSessionConfiguration
    public let plugins: [PluginType]
    
    let callbackQueue: DispatchQueue
    let sessionManager: Session
    var headers: HTTPHeaders
    var targetType: TargetType
    
    deinit {
      sessionManager.cancelAllRequests()
    }
    
    public init(
        configuration: NetworkURLSessionConfiguration,
        plugins: [PluginType] = [],
        hosts: [String],
        callbackQueue: DispatchQueue? = nil
    ) {
        self.configuration = configuration
        self.plugins = plugins
        self.callbackQueue = callbackQueue ?? DispatchQueue.main
        
        let servertrustManager = certificateVerification(hosts: hosts)
        let requestInterceptor = NetRequestInterceptor(plugins)
        sessionManager = Session(interceptor: requestInterceptor, serverTrustManager: servertrustManager)
    }
    
    public func request(_ targetType: DataTargetType, completion: Completion) {
        defaultHeaders()
        handleExtraHeaders(targetType.headers)
        let dnsResult = handleDNS(targetType)
        sessionManager.request(dnsResult.0,
                   method: targetType.method,
                   parameters: mergedParam(targetType),
                   encoding: configuration.requestParamaterEncodeType,
                   headers: headers) { [weak self] urlRequest in
            guard let self = self else { return }
            urlRequest = self.preparedRequest(urlRequest, target: targetType)
        }
        .cacheResponse(using: CachedResponseHandler)
        .validate(statusCode: targetType.validation.statusCodes).responseData { [weak self] res in
            guard let self = self else { return }
            if let originHost = dnsResult.1, res.error != nil {
                HTTPDNS.setDomainCacheFailed(originHost)
            }
            let response = Response(statusCode: res.response?.statusCode, data: res.data, request: res.request, response: res.response)
            var reponseResult: Result<Response, NetError>
            switch res.result {
            case .success:
                reponseResult = .success(response)
            case .failure(let error):
                reponseResult = .failure(NetError.underlying(error, response))
            }
            
            self.plugins.forEach { $0.didReceive(reponseResult, target: targetType) }
            
            self.callbackQueue.safeAsync {
                completion(reponseResult)
            }
        }
    }
    
}


extension NetworkProvider2 {
    
    private func mergedParam(_ target: TargetType)  -> [String: Any] {
        var mergedParams: [String: Any] = target.parameters ?? [String: Any]()
        plugins.forEach { plugin in
          if let extraParameters = plugin.extraParameters {
            extraParameters.forEach { (key, value) in
              mergedParams[key] = value
            }
          }
        }
        return mergedParams
    }
    
    private func preparedRequest(_ request: URLRequest, target: TargetType) -> URLRequest {
        return plugins.reduce(request) { $1.prepare($0, target: target) }
    }
    
    private func certificateVerification(hosts: [String]) ->  ServerTrustManager? {
        if configuration.httpsCertificateLocalVerify == true, let bundle = configuration.certificatesBundle {
            let policy = NetServerTrustEvaluating(certificates: bundle.af.certificates)
            var evaluators: [String: ServerTrustEvaluating]
            hosts.forEach { str in
                evaluators[str] = policy
            }
            return ServerTrustManager(evaluators: evaluators)
        }
        return nil
    }
}



extension NetworkProvider2 {
    
    private func defaultHeaders() {
        let headers = [String: String]()
        self.headers = HTTPHeaders(headers)
    }
    
    private func handleExtraHeaders(_ headers: [String: String]?) {
        guard let headers = headers else {
            return
        }
        headers.forEach { (k, v) in
            self.headers.add(name: k, value: v)
        }
    }
    
    private func handleHost(_ originHost: String) {
        headers.add(name: "Host", value: originHost)
    }
    
    private func checkShouldUseHTTPDNS(target: TargetType) -> Bool {
        if target is DataTargetType {
        return configuration.useHTTPDNS
      } else if let target = target as? DownloadTargetType {
        if let scheme = target.resource.url.scheme, scheme != "https" {
          return configuration.useHTTPDNS
        } else {
          return false
        }
      } else {
        return configuration.useHTTPDNS
      }
    }
    
    private func handleDNS(_ target: TargetType) -> (URL, String?) {
        let url = target.fullRequestURL

        guard checkShouldUseHTTPDNS(target: target) else {
          return (url, nil)
        }
        guard let host = url.host else {
          return (url, nil)
        }
        guard let dnsResult = HTTPDNS.query(host) else {
          return (url, nil)
        }

        guard let ipURL = url.network_replacingHost(host, with: dnsResult.ipAddress) else {
          return (url, nil)
        }
        handleHost(host)
        if dnsResult.fromCached {
            return (ipURL, host)
        } else {
            return (ipURL, nil)
        }
    }
}

