//
//  DownloadTargetType.swift
//  MixedNetworkSys
//
//  Created by jimmy on 08/04/2019.
//

import Foundation
import Alamofire

public protocol Downloadable {
  var url: URL { get }
  var resumeData: Data? { get }
}

extension URL: Downloadable {
  public var url: URL {
    return self
  }

  public var resumeData: Data? {
    return nil
  }
}

public protocol DownloadTargetType: TargetType {
  var resource: Downloadable { get }
  var downloadDestination: DownloadFileDestination { get }
}

extension DownloadTargetType {

  public var validation: ValidationType {
    return .successCodes
  }

  public var downloadDestination: DownloadFileDestination {
    return suggestedDownloadDestination()
  }

  public var method: HTTPMethod {
    return .get
  }

  public var parameters: [String: Any]? {
    return nil
  }

  public var headers: [String: String]? {
    return nil
  }

  public var fullRequestURL: URL {
    return resource.url
  }

  public var priority: Float {
    return 0.5
  }

  public var timeoutInterval: TimeInterval? {
    return nil
  }
}

public typealias DownloadFileDestination = (
  _ temporaryURL: URL,
  _ response: URLResponse
) -> (destinationURL: URL, options: DownloadRequest.Options)

public func suggestedDownloadDestination(
  for directory: FileManager.SearchPathDirectory = .documentDirectory,
  in domain: FileManager.SearchPathDomainMask = .userDomainMask
) -> DownloadFileDestination {
  return { temporaryURL, response in
    let directoryURLs = FileManager.default.urls(for: directory, in: domain)

    if let suggestedFilename = response.suggestedFilename, !directoryURLs.isEmpty {
      return (directoryURLs[0].appendingPathComponent(suggestedFilename), [])
    }

    return (temporaryURL, [])
  }
}
