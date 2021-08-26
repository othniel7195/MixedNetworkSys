//
//  AccountTestApi.swift
//  MixedNetworkSys
//
//  Created by jimmy on 2021/8/26.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import Foundation
import MixedNetworkSys


enum ApiTest: DataTargetType {
    case login
    case openHours(id: String)
    
    var baseURL: URL {
        return URL(string: "https://sobe-api-dev.shuinfo.com")!
    }
    
    var path: String {
        switch self {
        case .login:
            return "/store/pos/login"
        case .openHours:
            return "/store/pos/open_hours"
        }
        
    }
    
    var method: HTTPMethod {
        switch self {
        case .login:
            return .post
        case .openHours:
            return .get
        }
    }
    
    var parameters: [String : Any]? {
        switch self {
        case .login:
            return [
                "mobile": "15000965817",
                "code": "9876"
            ]
        case .openHours(let id):
            return [
                "id": id
            ]
        }
    }

    var validation: ValidationType {
        switch self {
        case .login:
            return .successCodes
        case .openHours:
            return .successCodes
        }
    }
    
    var headers: [String : String]? {
        switch self {
        case .login:
            return ["Content-Type": "application/json"]
        case .openHours:
            return ["Content-Type": "application/json"]
        }
        
    }
}


struct AccountLogin: Codable {
    let access_token: String?
    let refresh_token: String?
    let access_expires: String?
    let refresh_expires: String?
    let store_id: String?
    let stores: [Store]?
    
    enum CodingKeys: String, CodingKey {
        case access_token
        case refresh_token
        case access_expires
        case refresh_expires
        case store_id
        case stores
    }
}

struct Store: Codable {
    let store_id: String?
    let store_name: String?
    
    enum CodingKeys: String, CodingKey {
        case store_id
        case store_name
    }
}

struct Schedule: Codable {
    let opening_time: [OpeningTime]?
    let holiday_time: [HolidayTime]?
    let status: Int?
    
    enum CodingKeys: String, CodingKey {
        case opening_time
        case holiday_time
        case status
    }
}


struct OpeningTime: Codable {
    let weekday: [Int]?
    let opening_hours: [OpeningHours]?
    
    enum CodingKeys: String, CodingKey {
        case weekday
        case opening_hours
    }
}

struct OpeningHours: Codable {
    let start_time: Int?
    let end_time: Int?
    enum CodingKeys: String, CodingKey {
        case start_time
        case end_time
    }
}

struct HolidayTime: Codable {
    let start_day: Int?
    let end_day: Int?
    let opening_hours: [OpeningHours]?
    enum CodingKeys: String, CodingKey {
        case start_day
        case end_day
        case opening_hours
    }
}
