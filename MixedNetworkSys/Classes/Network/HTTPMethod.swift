//
//  HTTPMethod.swift
//  MixedNetworkSys
//
//  Created by jimmy on 08/03/2019.
//

import Foundation

public enum HTTPMethod: String {
  case options = "OPTIONS"
  case get = "GET"
  case head = "HEAD"
  case post = "POST"
  case put = "PUT"
  case patch = "PATCH"
  case delete = "DELETE"
  case trace = "TRACE"
  case connect = "CONNECT"
}
