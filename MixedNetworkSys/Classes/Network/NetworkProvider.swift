//
//  NetworkProvider.swift
//  MixedNetworkSys
//
//  Created by zf on 2021/8/22.
//

import Foundation
import Alamofire

/// Closure to be executed when a request has completed.
public typealias Completion = (_ result: Result<Response, NetError>) -> Void

public typealias ProgressBlock = (Progress) -> Void

/// QuicksilverProvider supports Data request, like REST API.
open class NetworkProvider {
  /// A list of plugins.
  /// e.g. for logging, network activity indicator or credentials.
  public let plugins: [PluginType]

  /// session Manager session configuration, includes https local verify and httpdns config
  public let configuration: NetworkURLSessionConfiguration

  deinit {
    sessionManager.cancelAllRequests()
  }

  /// 初始化
  /// - Parameter configuration: 配置
  /// - Parameter plugins: 插件列表。例如 Log 插件、权限验证插件、网络活动指示器插件
  /// - Parameter callbackQueue: 回调队列。若未指定，将使用 main
  public init(
    configuration: NetworkURLSessionConfiguration,
    plugins: [PluginType] = [],
    callbackQueue: DispatchQueue? = nil
  ) {
    self.callbackQueue = callbackQueue
    self.plugins = plugins
    self.configuration = configuration

    self.sessionManager = Alamofire.Session(session: <#T##URLSession#>, delegate: <#T##SessionDelegate#>, rootQueue: <#T##DispatchQueue#>)
    configSessionManager()
  }

  @discardableResult
  public func request(
    _ dataTarget: DataTargetType,
    callbackQueue: DispatchQueue? = .none,
    progress: ProgressBlock? = .none,
    completion: @escaping Completion
  ) -> NetworkDataTask {
    return requestNormal(
      dataTarget,
      callbackQueue: callbackQueue ?? self.callbackQueue,
      progress: progress,
      completion: completion
    )
  }

  @discardableResult
  public func download(
    _ downloadTarget: DownloadTargetType,
    callbackQueue: DispatchQueue? = .none,
    progress: ProgressBlock? = .none,
    completion: @escaping Completion
  ) -> NetworkDownloadTask {
    return requestNormal(
      downloadTarget,
      callbackQueue: callbackQueue ?? self.callbackQueue,
      progress: progress,
      completion: completion
    )
  }

  @discardableResult
  public func upload(
    _ uploadTarget: UploadTargetType,
    callbackQueue: DispatchQueue? = .none,
    progress: ProgressBlock? = .none,
    completion: @escaping Completion
  ) -> NetworkUploadTask {
    return requestNormal(
      uploadTarget,
      callbackQueue: callbackQueue ?? self.callbackQueue,
      progress: progress,
      completion: completion
    )
  }

  /// Only support Data Target Type.
  /// StubRequest Task only supports `cancel`, resume and suspend is not working.
  @discardableResult
  public func stubRequest(
    _ target: DataTargetType,
    callbackQueue: DispatchQueue?,
    completion: @escaping Completion,
    stubBehavior: StubBehavior
  ) -> NetworkDataTask {
    return performStubRequest(
      target,
      callbackQueue: callbackQueue,
      completion: completion,
      stubBehavior: stubBehavior
    )
  }

  // MARK: - Internal

  /// Propagated as callback queue. If nil - the main queue will be used.
  let callbackQueue: DispatchQueue?

  /// SessionManager for Rest API request
    let sessionManager: Alamofire.Session
}

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

extension NetworkProvider {
  func configSessionManager() {

  }

  /// Creates a function which, when called, executes the appropriate stubbing behavior for the given parameters.
  /// Only support Data Target Type.
  func createStubFunction(
    _ token: TaskToken,
    forTarget target: TargetType,
    withCompletion completion: @escaping Completion,
    plugins: [PluginType],
    request: URLRequest
  ) -> (() -> Void) {
    if let target = target as? DataTargetType {
      return {
        if token.isCancelled {
          self.cancelCompletion(completion, target: target)
          return
        }

        let validate = { (response: Response) -> Result<Response, NetError> in
          let validCodes = target.validation.statusCodes
          guard !validCodes.isEmpty else { return .success(response) }
          if validCodes.contains(response.statusCode) {
            return .success(response)
          } else {
            let statusError = NetError.statusCode(response)
            let error = NetError.underlying(statusError, response)
            return .failure(error)
          }
        }

        if let sampleResponseClosure = target.sampleResponse {
          switch sampleResponseClosure() {
          case .networkResponse(let statusCode, let data):
            let response = Response(
              statusCode: statusCode,
              data: data,
              request: request,
              response: nil
            )
            let result = validate(response)
            plugins.forEach { $0.didReceive(result, target: target) }
            completion(result)
          case .response(let customResponse, let data):
            let response = Response(
              statusCode: customResponse.statusCode,
              data: data,
              request: request,
              response: customResponse
            )
            let result = validate(response)
            plugins.forEach { $0.didReceive(result, target: target) }
            completion(result)
          case .networkError(let error):
            let error = NetError.underlying(error, nil)
            plugins.forEach { $0.didReceive(.failure(error), target: target) }
            completion(.failure(error))
          }
        } else {
          let error = NetError.underlying(
            NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown, userInfo: nil),
            nil
          )
          plugins.forEach { $0.didReceive(.failure(error), target: target) }
          completion(.failure(error))
        }
      }
    } else {
      fatalError("Stub function only support Data Target Type.")
    }
  }

  func requestNormal(
    _ target: TargetType,
    callbackQueue: DispatchQueue?,
    progress: ProgressBlock? = .none,
    completion: @escaping Completion
  ) -> TaskToken {
    let pluginsWithCompletion: Completion = { result in
      let processedResult = self.plugins.reduce(result) { $1.process($0, target: target) }
      completion(processedResult)
    }
    let result: (URLRequest?, NetError?, String?) = getTargetRequest(target)
    if let request = result.0 {
      let preparedRequest = self.plugins.reduce(request) { $1.prepare($0, target: target) }
      return performRequest(
        target,
        request: preparedRequest,
        callbackQueue: callbackQueue,
        progress: progress,
        originHost: result.2,
        completion: pluginsWithCompletion
      )
    } else {
      let task = TaskToken.simpleTask()
      let finalError = result.1 ?? NetError.requestMapping(target)
      pluginsWithCompletion(.failure(finalError))
      task.cancel()
      return task
    }
  }

  func performRequest(
    _ target: TargetType,
    request: URLRequest,
    callbackQueue: DispatchQueue?,
    progress: ProgressBlock?,
    originHost: String?,
    completion: @escaping Completion
  ) -> TaskToken {
    if let target = target as? DataTargetType {
      if case .never = configuration.stub {
        return sendRequest(
          target,
          request: request,
          callbackQueue: callbackQueue,
          progress: nil,
          originHost: originHost,
          completion: completion
        )
      } else if target.sampleResponse == nil {
        return sendRequest(
          target,
          request: request,
          callbackQueue: callbackQueue,
          progress: nil,
          originHost: originHost,
          completion: completion
        )
      } else {
        return performStubRequest(
          target,
          callbackQueue: callbackQueue,
          completion: completion,
          stubBehavior: configuration.stub
        )
      }
    } else if let target = target as? DownloadTargetType {
      return sendRequest(
        target,
        request: request,
        callbackQueue: callbackQueue,
        progress: progress,
        originHost: originHost,
        completion: completion
      )
    } else if let target = target as? UploadTargetType {
      return sendRequest(
        target,
        request: request,
        callbackQueue: callbackQueue,
        progress: progress,
        originHost: originHost,
        completion: completion
      )
    } else {
      fatalError("\(target) not support")
    }
  }

  func performStubRequest(
    _ target: DataTargetType,
    callbackQueue: DispatchQueue?,
    completion: @escaping Completion,
    stubBehavior: StubBehavior
  ) -> TaskToken {
    let callbackQueue = callbackQueue ?? self.callbackQueue
    let stubTask = TaskToken.stubTask()
    let requestResult = getTargetRequest(target)
    if let request = requestResult.0 {
      plugins.forEach { $0.willSend(request, target: target) }
      let stub: () -> Void = createStubFunction(
        stubTask,
        forTarget: target,
        withCompletion: completion,
        plugins: plugins,
        request: request
      )
      switch stubBehavior {
      case .immediate:
        safeAsync(queue: callbackQueue) {
          stubTask.finished()
          stub()
        }
      case .delayed(let delay):
        let killTimeOffset = Int64(CDouble(delay) * CDouble(NSEC_PER_SEC))
        let killTime = DispatchTime.now() + Double(killTimeOffset) / Double(NSEC_PER_SEC)
        (callbackQueue ?? DispatchQueue.main).asyncAfter(deadline: killTime) {
          stubTask.finished()
          stub()
        }
      case .never:
        fatalError("Method called to stub request when stubbing is disabled.")
      }
    } else {
      safeAsync(queue: callbackQueue) {
        stubTask.finished()
        completion(.failure(NetError.requestMapping(target)))
      }
    }
    return stubTask
  }

  func cancelCompletion(_ completion: Completion, target: TargetType) {
    let error = NetError.underlying(
      NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: nil),
      nil
    )
    plugins.forEach { $0.didReceive(.failure(error), target: target) }
    completion(.failure(error))
  }

  func getTargetRequest(_ target: TargetType) -> (URLRequest?, NetError?, String?) {
    func request(
      _ finalURL: URL,
      originHost: String? = nil,
      dnsResult: HTTPDNSResult? = nil
    ) -> (URLRequest?, NetError?, String?) {
      let fullUrlString = finalURL.absoluteString
      var serializationError: NSError?
      var mergedParams: [String: Any] = target.parameters ?? [:]
      plugins.forEach { plugin in
        if let extraParameters = plugin.extraParameters {
          extraParameters.forEach { (key, value) in
            mergedParams[key] = value
          }
        }
      }

      var request: NSMutableURLRequest
      if let target = target as? UploadTargetType,
        case .multipartForm(let constructingBody) = target.uploadType
      {
        request = requestSerializer.multipartFormRequest(
          withMethod: target.method.rawValue,
          urlString: fullUrlString,
          parameters: mergedParams,
          constructingBodyWith: { data in
            let updateData = MultipartformData(data: data)
            constructingBody(updateData)
          },
          error: &serializationError
        )
      }
      else {
        sessionManager.request(fullUrlString, method: Alamofire.HTTPMethod(rawValue: target.method.rawValue), parameters: mergedParams, encoder: configuration.requestParamaterEncodeType, headers: <#T##HTTPHeaders?#>, interceptor: <#T##RequestInterceptor?#>, requestModifier: <#T##Session.RequestModifier?##Session.RequestModifier?##(inout URLRequest) throws -> Void#>)
        request = sessionManager.request(
          withMethod: target.method.rawValue,
          urlString: fullUrlString,
          parameters: mergedParams,
          error: &serializationError
        )
      }

      if let timeout = target.timeoutInterval {
        request.timeoutInterval = timeout
      }

      if let error = serializationError {
        return (nil, NetError.underlying(error, nil), nil)
      } else {
        if let headers = target.headers {
          headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
          }
        }
        if let originHost = originHost {
          request.setValue(originHost, forHTTPHeaderField: "Host")
        }
        if let originHost = originHost, let dnsResult = dnsResult, dnsResult.fromCached {
          return (request as URLRequest, nil, originHost)
        } else {
          return (request as URLRequest, nil, nil)
        }
      }
    }

    let url = target.fullRequestURL

    guard checkShouldUseHTTPDNS(target: target) else {
      return request(url)
    }
    guard let host = url.host else {
      return request(url)
    }
    guard let dnsResult = HTTPDNS.query(host) else {
      return request(url)
    }

    guard let ipURL = url.network_replacingHost(host, with: dnsResult.ipAddress) else {
      return request(url)
    }

    return request(ipURL, originHost: host, dnsResult: dnsResult)
  }

  private func checkShouldUseHTTPDNS(target: TargetType) -> Bool {
    if let target = target as? DataTargetType {
      let useHTTPDNS: Bool
      switch configuration.stub {
      case .delayed, .immediate:
        if target.sampleResponse != nil {
          useHTTPDNS = false
        } else {
          useHTTPDNS = configuration.useHTTPDNS
        }
      case .never:
        useHTTPDNS = configuration.useHTTPDNS
      }
      return useHTTPDNS
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
}


extension NetworkProvider {
  func sendRequest(
    _ target: TargetType,
    request: URLRequest,
    callbackQueue: DispatchQueue?,
    progress: ProgressBlock?,
    originHost: String?,
    completion: @escaping Completion
  ) -> TaskToken {
    let plugins = self.plugins
    plugins.forEach { $0.willSend(request, target: target) }

    var taskToken: TaskToken!

    let completionHandler: (URLResponse?, Any?, Error?) -> Void = {
      response, responseObject, error in
      let httpURLResponse = response as? HTTPURLResponse
      let data = (responseObject ?? nil) as? Data
      if let originHost = originHost, error != nil {
        HTTPDNS.setDomainCacheFailed(originHost)
        CronetManager.updateHostResolverRule(host: originHost, ip: nil)
      }
      let result = convertResponseToResult(
        httpURLResponse,
        request: request,
        data: data,
        error: error,
        with: target
      )
      plugins.forEach { $0.didReceive(result, target: target) }

      safeAsync(queue: callbackQueue) {
        taskToken.finished()
        completion(result)
      }
    }

    let task: URLSessionTask
    if target as? DataTargetType != nil {
      task = af_dataTask(with: request, completionHandler: completionHandler)
    } else if let downloadTarget = target as? DownloadTargetType {
      task = af_downloadTask(
        with: request,
        downloadTarget: downloadTarget,
        callbackQueue: callbackQueue,
        progress: progress,
        completionHandler: completionHandler
      )
    } else if let uploadTarget = target as? UploadTargetType {
      task = af_uploadTask(
        with: request,
        target: uploadTarget,
        callbackQueue: callbackQueue,
        progress: progress,
        completionHandler: completionHandler
      )
    } else {
      fatalError("\(target) not support.")
    }
    task.priority = target.priority

    taskToken = TaskToken(sessionTask: task)
    taskToken.resume()

    return taskToken
  }
}

// MARK: - DataTargetType

extension QuicksilverProvider {
  private func af_dataTask(
    with request: URLRequest,
    completionHandler: @escaping (URLResponse?, Any?, Error?) -> Void
  ) -> URLSessionDataTask {
    return sessionManager.dataTask(
      with: request,
      uploadProgress: nil,
      downloadProgress: nil,
      completionHandler: completionHandler
    )
  }
}

// MARK: - UploadTargetType

extension QuicksilverProvider {
  private func af_uploadTask(
    with request: URLRequest,
    target: UploadTargetType,
    callbackQueue: DispatchQueue?,
    progress: ProgressBlock?,
    completionHandler: @escaping (URLResponse?, Any?, Error?) -> Void
  ) -> URLSessionUploadTask {
    let progressClusre: ((Progress) -> Void) = { _progress in
      let sendProgress: () -> Void = {
        progress?(_progress)
      }
      safeAsync(queue: callbackQueue) {
        sendProgress()
      }
    }

    switch target.uploadType {
    case .data(let data):
      return sessionManager.uploadTask(
        with: request,
        from: data,
        progress: progressClusre,
        completionHandler: completionHandler
      )
    case .file(let fileURL):
      return sessionManager.uploadTask(
        with: request,
        fromFile: fileURL,
        progress: progressClusre,
        completionHandler: completionHandler
      )
    case .multipartForm:
      return sessionManager.uploadTask(
        with: request,
        from: nil,
        progress: progress,
        completionHandler: completionHandler
      )
    }
  }
}

// MARK: - DownloadTargetType

extension QuicksilverProvider {
  private func af_downloadTask(
    with request: URLRequest,
    downloadTarget: DownloadTargetType,
    callbackQueue: DispatchQueue?,
    progress: ProgressBlock?,
    completionHandler: @escaping (URLResponse?, Any?, Error?) -> Void
  ) -> URLSessionDownloadTask {
    let progressClusre: (Progress) -> Void = { _progress in
      let sendProgress: () -> Void = {
        progress?(_progress)
      }
      safeAsync(queue: callbackQueue) {
        sendProgress()
      }
    }

    if let resumeData = downloadTarget.resource.resumeData {
      return sessionManager.downloadTask(
        withResumeData: resumeData,
        progress: progressClusre,
        destination: downloadTarget.downloadDestination,
        completionHandler: { response, url, error in
          let data = url?.path.data(using: .utf8)
          completionHandler(response, data, error)
        }
      )
    } else {
      return sessionManager.downloadTask(
        with: request,
        progress: progressClusre,
        destination: downloadTarget.downloadDestination,
        completionHandler: { response, url, error in
          let data = url?.path.data(using: .utf8)
          completionHandler(response, data, error)
        }
      )
    }
  }
}


private func convertResponseToResult(
  _ response: HTTPURLResponse?,
  request: URLRequest?,
  data: Data?,
  error: Error?,
  with target: TargetType
) -> Result<Response, QuicksilverError> {
  if let response = response, error == nil {
    let customResponse = Response(
      statusCode: response.statusCode,
      data: data ?? Data(),
      request: request,
      response: response
    )
    if target.validation.statusCodes.contains(response.statusCode) {
      return .success(customResponse)
    } else {
      let error = QuicksilverError.statusCode(customResponse)
      return .failure(error)
    }
  } else {
    let statusCode = response?.statusCode ?? 400  // client error with the case about response is nil
    let customResponse = Response(
      statusCode: statusCode, data: data ?? Data(), request: request, response: response)
    let error = QuicksilverError.underlying(
      error ?? NSError(
        domain: NSURLErrorDomain,
        code: NSURLErrorUnknown,
        userInfo: [NSLocalizedDescriptionKey: "Request failed with unknown Error"]
      ),
      customResponse
    )
    return .failure(error)
  }
}
