//
//  AccountTestApi.swift
//  MixedNetworkSys
//
//  Created by jimmy on 2021/8/26.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import Foundation
import MixedNetworkSys


enum AccountTest: DataTargetType {
    case login
    
    var baseURL: URL {
        return URL(string: "https://sobe-api-dev.shuinfo.com")!
    }
    
    var path: String {
        switch self {
        case .login:
            return "/account/login"
        }
        
    }
    
    var method: HTTPMethod {
        switch self {
        case .login:
            return .post
        }
    }
    
    var parameters: [String : Any]? {
        switch self {
        case .login:
            return [
                "mobile": "15000965817",
                "code": "9876"
            ]
        
        }
    }
    
    var headers: [String : String]? {
        switch self {
        case .login:
            return ["Content-Type": "application/json"]
        }
        
    }
}
