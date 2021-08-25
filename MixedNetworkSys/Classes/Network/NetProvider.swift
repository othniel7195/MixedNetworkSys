//
//  NetProvider.swift
//  MixedNetworkSys
//
//  Created by zf on 2021/8/24.
//

import Foundation

public final class NetProvider {
  /// 降级策略
  public enum FallbackStrategy {
    /// Normal -> HTTPDNS -> CDN
    case `default`

    /// HTTPDNS -> CDN/Normal
    case httpDNSFirst

    /// CDN -> Normal
    case oversea
  }

  private let fallbackStrategy: FallbackStrategy
  private let normalStage: NetworkProvider
  private let dnsStage: NetworkProvider
  private let cdnStage: NetworkProvider
  private let cdnHostOfOriginalHost: ((String) -> String?)?

  ///plugins: 插件列表。例如 Log 插件、权限验证插件、网络活动指示器插件
  ///callbackQueue: 回调队列。默认为 main
  ///fallbackStrategy: 降级策略。默认为 default
  ///cdnHostOfOriginalHost: 原始 Host 到 CDN Host 的映射
  public init(
    plugins: [PluginType] = [],
    callbackQueue: DispatchQueue = .main,
    fallbackStrategy: FallbackStrategy = .default,
    cdnHostOfOriginalHost: ((String) -> String?)? = nil
  ) {
    self.fallbackStrategy = fallbackStrategy
    
    self.normalStage = .init(
        configuration: .init(
        useHTTPDNS: false
      ),
      plugins: plugins,
      callbackQueue: callbackQueue
    )
    
    
    
    self.dnsStage = .init(
      configuration: .init(
        useHTTPDNS: true,
      ),
      plugins: plugins,
      callbackQueue: callbackQueue
    )
    self.cdnStage = .init(
      configuration: .init(
        useHTTPDNS: true,
      ),
      plugins: plugins,
      callbackQueue: callbackQueue
    )
    self.cdnHostOfOriginalHost = cdnHostOfOriginalHost
  }

  /// 发起请求
  /// - Parameter dataTarget: 数据 Target
  /// - Parameter callbackQueue: 回调队列。默认为 nil（进而使用 main）
  /// - Parameter progress: 进度报告回调
  /// - Parameter completion: 完成回调
  @discardableResult
  public func request(
    _ dataTarget: DataTargetType,
    callbackQueue: DispatchQueue? = nil,
    progress: ProgressBlock? = nil,
    completion: @escaping Completion
  ) -> QuicksilverDataTask {
    switch fallbackStrategy {
    case .default:
      return defaultRequest(
        dataTarget,
        callbackQueue: callbackQueue,
        progress: progress,
        completion: completion
      )
    case .httpDNSFirst:
      return httpDNSFirstRequest(
        dataTarget,
        callbackQueue: callbackQueue,
        progress: progress,
        completion: completion
      )
    case .oversea:
      return overseaRequest(
        dataTarget,
        callbackQueue: callbackQueue,
        progress: progress,
        completion: completion
      )
    }
  }
}

extension NetProvider {
  private func defaultRequest(
    _ dataTarget: DataTargetType,
    callbackQueue: DispatchQueue?,
    progress: ProgressBlock?,
    completion: @escaping Completion
  ) -> QuicksilverDataTask {
    let task = TaskToken.simpleTask()

    // 先正常请求
    let normalStageTask = normalStage.request(
      dataTarget,
      callbackQueue: callbackQueue,
      progress: progress,
      completion: { result in
        switch result {
        case .success(let response):
          completion(.success(response))
        case .failure(let error):
          #if DEBUG
          print("❌ normalStage-error:", error)
          #endif

          guard error.isUnderlyingError else {
            completion(.failure(error))
            return
          }

          guard let host = dataTarget.fullRequestURL.host else {
            completion(.failure(error))
            return
          }

          // 失败后，尝试开启 HTTPDNS 再请求
          HTTPDNS.query(host) { result in
            if let result = result {
              #if DEBUG
              print("HTTPDNS:", host, result.ipAddress)
              #endif

              let dnsStageTask = self.dnsStage.request(
                dataTarget,
                callbackQueue: callbackQueue,
                progress: progress,
                completion: { result in
                  switch result {
                  case .success(let response):
                    completion(.success(response))
                  case .failure(let error):
                    #if DEBUG
                    print("❌ dnsStage-error:", error)
                    #endif

                    guard error.isUnderlyingError else {
                      completion(.failure(error))
                      return
                    }

                    // 换了 HTTPDNS 也不行，最后用 CDN 请求
                    guard let cdnBaseURL = self.cdnBaseURL(of: dataTarget.baseURL) else {
                      completion(.failure(error))
                      return
                    }

                    let cdnRequestTask = self.cdnRequest(
                      cdnBaseURL: cdnBaseURL,
                      dataTarget: dataTarget,
                      callbackQueue: callbackQueue,
                      progress: progress,
                      completion: completion
                    )
                    task.restart(with: cdnRequestTask)
                  }
                }
              )
              task.restart(with: dnsStageTask)
            } else {
              // HTTPDNS 查询失败，就用 CDN 请求
              guard let cdnBaseURL = self.cdnBaseURL(of: dataTarget.baseURL) else {
                completion(.failure(error))
                return
              }

              let cdnRequestTask = self.cdnRequest(
                cdnBaseURL: cdnBaseURL,
                dataTarget: dataTarget,
                callbackQueue: callbackQueue,
                progress: progress,
                completion: completion
              )
              task.restart(with: cdnRequestTask)
            }
          }
        }
      }
    )
    task.restart(with: normalStageTask)

    return task
  }
}

extension NetProvider {
  private func httpDNSFirstRequest(
    _ dataTarget: DataTargetType,
    callbackQueue: DispatchQueue?,
    progress: ProgressBlock?,
    completion: @escaping Completion
  ) -> QuicksilverDataTask {
    let task = TaskToken.simpleTask()

    guard let host = dataTarget.fullRequestURL.host else {
      return task
    }

    // 尝试开启 HTTPDNS 再请求
    HTTPDNS.query(host) { result in
      if let result = result {
        #if DEBUG
        print("HTTPDNS:", host, result.ipAddress)
        #endif

        let dnsStageTask = self.dnsStage.request(
          dataTarget,
          callbackQueue: callbackQueue,
          progress: progress,
          completion: { result in
            switch result {
            case .success(let response):
              completion(.success(response))
            case .failure(let error):
              #if DEBUG
              print("❌ dnsStage-error:", error)
              #endif

              guard error.isUnderlyingError else {
                completion(.failure(error))
                return
              }

              // 换了 HTTPDNS 也不行，最后用 CDN 请求
              guard let cdnBaseURL = self.cdnBaseURL(of: dataTarget.baseURL) else {
                completion(.failure(error))
                return
              }

              let cdnRequestTask = self.cdnRequest(
                cdnBaseURL: cdnBaseURL,
                dataTarget: dataTarget,
                callbackQueue: callbackQueue,
                progress: progress,
                completion: completion
              )
              task.restart(with: cdnRequestTask)
            }
          }
        )
        task.restart(with: dnsStageTask)
      } else {
        #if DEBUG
        print("HTTPDNS failed")
        #endif

        // HTTPDNS 查询失败，就尝试用 CDN 请求
        if let cdnBaseURL = self.cdnBaseURL(of: dataTarget.baseURL) {
          let cdnRequestTask = self.cdnRequest(
            cdnBaseURL: cdnBaseURL,
            dataTarget: dataTarget,
            callbackQueue: callbackQueue,
            progress: progress,
            completion: completion
          )
          task.restart(with: cdnRequestTask)
        } else {
          // 否则正常请求
          let normalStageTask = self.normalStage.request(
            dataTarget,
            callbackQueue: callbackQueue,
            progress: progress,
            completion: completion
          )
          task.restart(with: normalStageTask)
        }
      }
    }

    return task
  }
}

extension NetProvider {
  private func overseaRequest(
    _ dataTarget: DataTargetType,
    callbackQueue: DispatchQueue?,
    progress: ProgressBlock?,
    completion: @escaping Completion
  ) -> QuicksilverDataTask {
    // HTTPDNS 查询失败，就尝试用 CDN 请求
    if let cdnBaseURL = self.cdnBaseURL(of: dataTarget.baseURL) {
      return self.cdnRequest(
        cdnBaseURL: cdnBaseURL,
        dataTarget: dataTarget,
        callbackQueue: callbackQueue,
        progress: progress,
        completion: completion
      )
    } else {
      // 否则正常请求
      return self.normalStage.request(
        dataTarget,
        callbackQueue: callbackQueue,
        progress: progress,
        completion: completion
      )
    }
  }
}

extension NetProvider {
  private func cdnRequest(
    cdnBaseURL: URL,
    dataTarget: DataTargetType,
    callbackQueue: DispatchQueue?,
    progress: ProgressBlock?,
    completion: @escaping Completion
  ) -> QuicksilverDataTask {
    struct Endpoint: DataTargetType, TargetType {
      var baseURL: URL
      var path: String
      var method: HTTPMethod
      var parameters: [String: Any]?
      var headers: [String: String]?
      var validation: ValidationType
      var priority: Float
      var timeoutInterval: TimeInterval?
    }

    let endpoint = Endpoint(
      baseURL: cdnBaseURL,
      path: dataTarget.path,
      method: dataTarget.method,
      parameters: dataTarget.parameters,
      headers: dataTarget.headers,
      validation: dataTarget.validation,
      priority: dataTarget.priority,
      timeoutInterval: dataTarget.timeoutInterval
    )

    return self.cdnStage.request(
      endpoint,
      callbackQueue: callbackQueue,
      progress: progress,
      completion: { result in
        switch result {
        case .success(let response):
          completion(.success(response))
        case .failure(let error):
          #if DEBUG
          print("❌ cdnStage-error:", error)
          #endif

          completion(.failure(error))
        }
      }
    )
  }
}

extension NetProvider {
  private func cdnBaseURL(of baseURL: URL) -> URL? {
    guard let host = baseURL.host else { return nil }
    guard let cdnHost = cdnHostOfOriginalHost?(host) else { return nil }
    return baseURL.quicksilver_replacingHost(host, with: cdnHost)
  }
}

extension QuicksilverError {
  fileprivate var isUnderlyingError: Bool {
    switch self {
    case .underlying:
      return true
    case .requestMapping:
      return false
    case .statusCode:
      return false
    case .jsonMapping:
      return false
    case .stringMapping:
      return false
    case .objectMapping:
      return false
    }
  }
}
