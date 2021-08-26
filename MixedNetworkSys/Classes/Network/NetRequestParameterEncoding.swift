//
//  NetRequestParameterEncoding.swift
//  MixedNetworkSys
//
//  Created by jimmy on 2021/8/26.
//

import Foundation
import Alamofire


public struct NetRequestParameterEncoding: ParameterEncoding {
    
    public static var `default`: NetRequestParameterEncoding { NetRequestParameterEncoding() }
    
    public func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var method: Alamofire.HTTPMethod?
        do {
            method = try urlRequest.asURLRequest().method
        } catch {
            #if DEBUG
            print("❌ encode request params error:", error)
            #endif
            throw error
        }
        
        guard let method = method else {
            throw NSError(domain: "\(urlRequest) -> method is nil", code: -99999, userInfo: nil)
        }
        switch method {
        case .get:
            return try URLEncoding.default.encode(urlRequest, with: parameters)
        default:
            return try JSONEncoding.default.encode(urlRequest, with: parameters)
        }
    }
}
