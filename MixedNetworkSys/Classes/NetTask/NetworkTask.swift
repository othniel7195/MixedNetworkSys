//
//  NetworkTask.swift
//  Alamofire
//
//  Created by jimmy on 2021/8/30.
//

import Foundation

public protocol NetworkTask {
  var isCancelled: Bool { get }
  var isRunning: Bool { get }
  var taskIdentifier: Int { get }

  func resume()
  func suspend()
  func cancel()
}

public protocol NetworkDataTask: NetworkTask {}

public protocol NetworkUploadTask: NetworkTask {}

public protocol NetworkDownloadTask: NetworkTask {
  func cancel(byProducingResumeData completionHandler: @escaping (Data?) -> Void)
}
