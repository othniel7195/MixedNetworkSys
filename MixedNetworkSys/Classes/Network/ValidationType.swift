//
//  ValidationType.swift
//  MixedNetworkSys
//
//  Created by jimmy on 08/03/2019.
//

import Foundation

public enum ValidationType: Equatable {
  ///only 2xx
  case successCodes
  ///success codes and redirection codes (only 2xx and 3xx)
  case successAndRedirectCodes
  case customCodes([Int])
  
  var statusCodes: [Int] {
    switch self {
    case .successCodes:
      return Array(200..<300)
    case .successAndRedirectCodes:
      return Array(200..<400)
    case .customCodes(let codes):
      return codes
    }
  }
}
