//
//  NetworkDownloadTask.swift
//  MixedNetworkSys
//
//  Created by zf on 2021/8/22.
//

import Foundation

public protocol NetworkDownloadTask: NetworkTask {
  func cancel(byProducingResumeData completionHandler: @escaping (Data?) -> Void)
}
