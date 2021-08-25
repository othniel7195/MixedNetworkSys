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


func safeAsync(queue: DispatchQueue?, closure: @escaping () -> Void) {
  switch queue {
  case .none:
    if Thread.isMainThread {
      closure()
    } else {
      DispatchQueue.main.async {
        closure()
      }
    }
  case .some(let runQueue):
    runQueue.async {
      closure()
    }
  }
}

public class NetworkProvider {
    
    private let configuration: NetworkURLSessionConfiguration
    private let plugins: [PluginType]
    private let callbackQueue: DispatchQueue
    private var sessionManager: Session?
    private var headers: HTTPHeaders?
    
    deinit {
      sessionManager?.cancelAllRequests()
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
        
        defaultHeaders()

        sessionManager = Session(configuration: configuration.urlSessionConfiguration, interceptor: requestInterceptor, serverTrustManager: servertrustManager)
    }
    
    public func request(_ targetType: DataTargetType,
                        callbackQueue: DispatchQueue? = .none,
                        completion: @escaping Completion) {
        
        
        
        let dataRequest: DataRequest? = getTargetRequest(targetType)
        if let urlRequest = dataRequest?.request {
            preparedRequest(urlRequest, target: targetType)
        }
        
        
        sessionManager?.request(dnsResult.0,
                   method: targetType.method,
                   parameters: mergedParam(targetType),
                   encoding: configuration.requestParamaterEncodeType,
                   headers: headers) { [weak self]  urlRequest in
            guard let self = self else { return }
            urlRequest.timeoutInterval = targetType.timeoutInterval ?? 0
            urlRequest = self.preparedRequest(urlRequest, target: targetType)
            
        }
        .validate(statusCode: targetType.validation.statusCodes)
        .responseData { [weak self] res in
            guard let self = self else { return }
            self.removeDNS(dnsResult.1, error: res.error)
            self.responseCompletionHandler(targetType, data: res.data, request: res.request, response: res.response, result: res.result, callbackQueue: callbackQueue, completion: completion)
        }
    }
    
    public func download(_ targetType: DownloadTargetType,
                         callbackQueue: DispatchQueue? = .none,
                         progress: ProgressBlock?,
                         completion: @escaping Completion) {
        
        let progressClusre: (Progress) -> Void = { _progress in
          let sendProgress: () -> Void = {
            progress?(_progress)
          }
          safeAsync(queue: callbackQueue) {
            sendProgress()
          }
        }
        
        if let resumeData = targetType.resource.resumeData {
            sessionManager?.download(resumingWith: resumeData, to: targetType.downloadDestination)
                .downloadProgress(closure: { progress in
                    progressClusre(progress)
                }).validate(statusCode: targetType.validation.statusCodes)
                .responseData { [weak self] res in
                    guard let self = self else { return }
                    let data = res.response?.url?.path.data(using: .utf8)
                    self.responseCompletionHandler(targetType,
                                                   data: data,
                                                   request: res.request,
                                                   response: res.response,
                                                   result: res.result,
                                                   callbackQueue: callbackQueue,
                                                   completion: completion)
            }
        } else {
            handleExtraHeaders(targetType.headers)
            let dnsResult = handleDNS(targetType)
            sessionManager?.download(dnsResult.0,
                                     method: targetType.method,
                                     parameters: mergedParam(targetType),
                                     encoding: configuration.requestParamaterEncodeType,
                                     headers: headers,
                                     requestModifier: { [weak self] urlRequest in
                                        guard let self = self else { return }
                                        urlRequest = self.preparedRequest(urlRequest, target: targetType)
                
                                     }, to: targetType.downloadDestination).downloadProgress(closure: { progress in
                                        progressClusre(progress)
                                     }).validate(statusCode: targetType.validation.statusCodes)
                .responseData(completionHandler: { [weak self] res in
                    guard let self = self else { return }
                    let data = res.response?.url?.path.data(using: .utf8)
                    self.responseCompletionHandler(targetType,
                                                   data: data,
                                                   request: res.request,
                                                   response: res.response,
                                                   result: res.result,
                                                   callbackQueue: callbackQueue,
                                                   completion: completion)
                })
        }
        
    }
    
    public func upload(_ targetType: UploadTargetType,
                       callbackQueue: DispatchQueue? = .none,
                       progress: ProgressBlock?,
                       completion: @escaping Completion) {
        

    }
    
}



extension NetworkProvider {
    
    
    private func getTargetRequest<T: Request>(_ targetType: TargetType) -> T? {
        
        handleExtraHeaders(targetType.headers)
        let dnsResult = handleDNS(targetType)
        let mergedParams = mergedParam(targetType)
        let method = targetType.method
        let timeout = targetType.timeoutInterval ?? 0
        var request: T?
        
        if targetType is DataTargetType {
            request = sessionManager?.request(dnsResult.0,
                       method: method,
                       parameters: mergedParams,
                       encoding: configuration.requestParamaterEncodeType,
                       headers: headers,
                       requestModifier: { [weak self] urlRequest in
                        guard let self = self else { return }
                        urlRequest.timeoutInterval = timeout
                        urlRequest = self.preparedRequest(urlRequest, target: targetType)
                       }) as? T
            
        } else if let downloadType = targetType as? DownloadTargetType {
            if let resumeData = downloadType.resource.resumeData {
                request = sessionManager?.download(resumingWith: resumeData, to: downloadType.downloadDestination) as? T
            } else {
                request = sessionManager?.download(dnsResult.0,
                                         method: method,
                                         parameters: mergedParams,
                                         encoding: configuration.requestParamaterEncodeType,
                                         headers: headers,
                                         requestModifier: { urlRequest in
                                            urlRequest.timeoutInterval = timeout
                                         }) as? T
            }
        } else if let uploadTargetType = targetType as? UploadTargetType {
            switch uploadTargetType.uploadType {
            case .data(let data):
                request = sessionManager?.upload(data,
                                                 to: dnsResult.0,
                                                 method: method,
                                                 headers: headers,
                                                 requestModifier: { urlRequest in
                    urlRequest.timeoutInterval = timeout
                }) as? T
            case .file(let fileURL):
                request = sessionManager?.upload(fileURL,
                                                 to: dnsResult.0,
                                                 method: method,
                                                 headers: headers,
                                                 requestModifier: { urlRequest in
                    urlRequest.timeoutInterval = timeout
                }) as? T
            case .multipartForm(let constructingBody):
                request = sessionManager?.upload(multipartFormData: constructingBody,
                                                 to: dnsResult.0,
                                                 method: method,
                                                 headers: headers,
                                                 requestModifier: { urlRequest in
                    urlRequest.timeoutInterval = timeout
                }) as? T
            
            }
        }
        
        return request 
    }
    
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
    
    private func certificateVerification(hosts: [String]) ->  NetServerTrustManager? {
        if configuration.httpsCertificateLocalVerify == true, let bundle = configuration.certificatesBundle {
            let policy = NetServerTrustEvaluating(certificates: bundle.af.certificates)
            var evaluators: [String: ServerTrustEvaluating] =  [String: ServerTrustEvaluating]()
            hosts.forEach { str in
                evaluators[str] = policy
            }
            return NetServerTrustManager(evaluators: evaluators)
        }
        return nil
    }
    
    private func removeDNS(_ originHost: String?, error: Error?) {
        if let originHost = originHost, error != nil {
            HTTPDNS.setDomainCacheFailed(originHost)
        }
    }
    
    private func responseCompletionHandler(_ target: TargetType,
                                             data: Data?,
                                             request: URLRequest?,
                                             response: HTTPURLResponse?,
                                             result: Result<Data, AFError>,
                                             callbackQueue: DispatchQueue?,
                                             completion: @escaping Completion) {
        let response = Response(statusCode: response?.statusCode, data: data, request: request, response: response)
        var reponseResult: Result<Response, NetError>
        switch result {
        case .success:
            reponseResult = .success(response)
        case .failure(let error):
            reponseResult = .failure(NetError.underlying(error, response))
        }
        
        plugins.forEach { $0.didReceive(reponseResult, target: target) }
        
        safeAsync(queue: (callbackQueue ?? self.callbackQueue), closure: {
            let processedResult = self.plugins.reduce(reponseResult) {
                $1.process($0, target: target)
            }
            completion(processedResult)
        })
        
    }
}



extension NetworkProvider {
    
    private func defaultHeaders() {
        let headers = [String: String]()
        self.headers = HTTPHeaders(headers)
    }
    
    private func handleExtraHeaders(_ headers: [String: String]?) {
        guard let headers = headers else {
            return
        }
        headers.forEach { (k, v) in
            self.headers?.add(name: k, value: v)
        }
    }
    
    private func handleHost(_ originHost: String) {
        headers?.add(name: "Host", value: originHost)
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

