//
//  NetworkTask.swift
//  MixedNetworkSys
//
//  Created by zf on 2021/8/22.
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
