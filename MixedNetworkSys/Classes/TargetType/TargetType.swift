//
//  TargetType.swift
//  MixedNetworkSys
//
//  Created by jimmy on 08/24/2021.
//

import Foundation
import Alamofire

public protocol TargetType {
    
    var validation: ValidationType { get }
    var method: HTTPMethod { get }
    var parameters: [String: Any]? { get }
    var headers: [String: String]? { get }
    ///final url
    var fullRequestURL: URL { get }
    ///0.0 (lowest) and 1.0 (highest).
    ///default == NSURLSessionTaskPriorityDefault 0.5
    var priority: Float { get }
    /// timeout interval is seconds
    var timeoutInterval: TimeInterval? { get }
}

extension TargetType {
    public var timeoutInterval: TimeInterval? {
        return nil
    }
}
