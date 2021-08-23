//
//  Test.swift
//  MixedNetworkSys
//
//  Created by zf on 2021/8/23.
//

import Foundation


class Test {
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
      let result: (URLRequest?, QuicksilverError?, String?) = getTargetRequest(target)
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
        let finalError = result.1 ?? QuicksilverError.requestMapping(target)
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
    
    func cancelCompletion(_ completion: Completion, target: TargetType) {
      let error = QuicksilverError.underlying(
        NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: nil),
        nil
      )
      plugins.forEach { $0.didReceive(.failure(error), target: target) }
      completion(.failure(error))
    }

    func getTargetRequest(_ target: TargetType) -> (URLRequest?, QuicksilverError?, String?) {
      func request(
        _ finalURL: URL,
        originHost: String? = nil,
        dnsResult: HTTPDNSResult? = nil
      ) -> (URLRequest?, QuicksilverError?, String?) {
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
          request = requestSerializer.request(
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
          return (nil, QuicksilverError.underlying(error, nil), nil)
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

      if configuration.useCronet {
        CronetManager.updateHostResolverRule(host: host, ip: dnsResult.ipAddress)

        return request(url)
      } else {
        guard let ipURL = url.quicksilver_replacingHost(host, with: dnsResult.ipAddress) else {
          return request(url)
        }

        return request(ipURL, originHost: host, dnsResult: dnsResult)
      }
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
    
    @discardableResult
    public func request(
      _ dataTarget: DataTargetType,
      callbackQueue: DispatchQueue? = .none,
      progress: ProgressBlock? = .none,
      completion: @escaping Completion
    ) -> QuicksilverDataTask {
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
    ) -> QuicksilverDownloadTask {
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
    ) -> QuicksilverUploadTask {
      return requestNormal(
        uploadTarget,
        callbackQueue: callbackQueue ?? self.callbackQueue,
        progress: progress,
        completion: completion
      )
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
