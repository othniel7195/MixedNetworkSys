//
//  AccessTokenPlugin.swift
//  MixedNetworkSys
//
//  Created by jimmy on 08/05/2019.
//

import Foundation

public protocol AccessTokenAuthorizable {
  ///authorization header to use for requests
  var authorizationType: AuthorizationType { get }
}

public enum AuthorizationType: RawRepresentable {

  public typealias RawValue = String
  
  case none
  case basic
  case customType(String)
  
  public init?(rawValue: String) {
    if rawValue.isEmpty {
      self = .none
    } else {
      switch rawValue {
      case "Basic":
        self = .basic
      default:
        self = .customType(rawValue)
      }
    }
  }
  
  public var rawValue: String {
    switch self {
    case .basic:
      return "Basic"
    case .customType(let value):
      return value
    default:
      return ""
    }
  }
  
}

public struct AccessTokenPlugin: PluginType {

  public let tokenClosure: () -> String?
  
  public init(tokenClosure: @escaping @autoclosure () -> String?) {
    self.tokenClosure = tokenClosure
  }
  
  public func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
    guard let authorizable = target as? AccessTokenAuthorizable else {
      return request
    }
    let authorizationType = authorizable.authorizationType
    var request = request
    if let token = tokenClosure() {
      switch authorizationType {
      case .none:
        break
      default:
        let authValue = authorizationType.rawValue + " "  + token
        request.addValue(authValue, forHTTPHeaderField: "Authorization")
      }
    }
    return request
  }
}
