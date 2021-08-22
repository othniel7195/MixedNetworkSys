//
//  DataTargetType.swift
//  MixedNetworkSys
//
//  Created by jimmy on 08/04/2019.
//

import Foundation

public protocol DataTargetType: TargetType {
  var baseURL: URL { get }
  var path: String { get }
  var sampleResponse: SampleResponseClosure? { get }
}

extension DataTargetType {
  
  public var validation: ValidationType {
    return .successCodes
  }

  public var sampleResponse: SampleResponseClosure? {
    return nil
  }

  public var parameters: [String: Any]? {
    return nil
  }

  public var headers: [String: String]? {
    return nil
  }

  public var fullRequestURL: URL {
    return makeFullRequestURL(withBaseURL: baseURL)
  }

  public var priority: Float {
    return 0.5
  }

  public var timeoutInterval: TimeInterval? {
    return nil
  }

  public func makeFullRequestURL(withBaseURL baseURL: URL) -> URL {
    var finalBaseURL = baseURL
    if finalBaseURL.path.count > 0 && !finalBaseURL.absoluteString.hasSuffix("/") {
      finalBaseURL = finalBaseURL.appendingPathComponent("")
    }
    if let url = URL(string: path, relativeTo: finalBaseURL) {
      return url
    } else {
      fatalError("\(baseURL) relative \(path) failed, please double check.")
    }
  }
}


public enum SampleResponse {
  case networkResponse(Int, Data)
  case response(HTTPURLResponse, Data)
  case networkError(NSError)
}

public typealias SampleResponseClosure = () -> SampleResponse
