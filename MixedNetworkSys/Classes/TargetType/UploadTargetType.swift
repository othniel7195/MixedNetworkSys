//
//  UploadTargetType.swift
//  MixedNetworkSys
//
//  Created by jimmy on 08/04/2019.
//

import Foundation
import Alamofire

public enum UploadType {
  case file(URL)
  case data(Data)
  case multipartForm(constructingBody: (MultipartFormData) -> Void)
}

public protocol UploadTargetType: TargetType {
  var uploadURL: URL { get }
  var uploadType: UploadType { get }
}

extension UploadTargetType {
  public var validation: ValidationType {
    return .successCodes
  }

  public var method: HTTPMethod {
    return .post
  }

  public var parameters: [String: Any]? {
    return nil
  }

  public var headers: [String: String]? {
    return nil
  }

  public var fullRequestURL: URL {
    return uploadURL
  }

  public var priority: Float {
    return 0.5
  }

  public var timeoutInterval: TimeInterval? {
    return nil
  }
}
