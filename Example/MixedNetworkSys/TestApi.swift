//
//  AccountTestApi.swift
//  MixedNetworkSys
//
//  Created by jimmy on 2021/8/26.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import Foundation
import MixedNetworkSys
import Then


enum ApiTest: DataTargetType, AccessTokenAuthorizable {
 
    case login
    case openHours(id: String)
    
    var baseURL: URL {
        return URL(string: "https://sobe-api-test.shuinfo.com")!
    }
    
    var authorizationType: AuthorizationType {
        return .bearer
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
        case .openHours:
            return nil
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
            return nil
        case .openHours:
            return ["channel": "5"]
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


struct ApiTestEng {
    
    func createProvider() -> NetworkProvider {
        let auth1 = AccessTokenPlugin(tokenClosure: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY2NvdW50IjoyNTAwMDksImV4cCI6MTYzMDgzMzIxMSwiaWF0IjoxNjI5OTY5MjExLCJpc3MiOiJodHRwczovL3d3dy5zaHVpbmZvLmNvbSIsInBvcy1hY2NvdW50IjoyNTAwMDksInBvcy1kZXZpY2UiOiIiLCJwb3Mtc3RvcmUiOiI2MGY2NzcxYjgwYmQxNWUyMjZkYzQ0YjciLCJ0ZW5hbnQiOjQwMDAzfQ.Y_YahDeqh3IfPxWrf6-Ek9hgwEJ9wMLp4Lxp4JW3AQE")
        let provider = NetworkProvider(configuration: .init(useHTTPDNS: false), plugins: [auth1], hosts: ["sobe-api-dev.shuinfo.com"])
        return provider
    }
    
    //"{\"schedule\":{\"opening_time\":[{\"weekday\":[1,2,3,4,5,6,7],\"opening_hours\":[{\"start_time\":28800,\"end_time\":86399}]}],\"holiday_time\":[]},\"status\":1}"
    func openHours(_ provider: NetworkProvider, compl: @escaping (_ schedule: Schedule?, _ err: Error?) -> Void) {
        provider.request(ApiTest.openHours(id: "")) { result in
            switch result {
            case .success(let response):
                let string = try? response.mapString()
                print("schedule data: \(String(describing: string))")
                
                let json = try? response.mapJSON()
                print("schedule data json: \(String(describing: json))")
                
                let scheduleData = try? response.map(Schedule.self, atKeyPath: "schedule")
                print("schedule data: \(String(describing: scheduleData))")
                compl(scheduleData, nil)
            case .failure(let error):
                print("schedule data error: \(error)")
                compl(nil, error)
            }
        }
    }
    
    
    func openHoursNew<T: Codable>(_ provider: NetworkProvider) -> Promise<T> {
        return Promise { reslove, reject in
            provider.request(ApiTest.openHours(id: "")) { result in
                switch result {
                case .success(let response):
                    let string = try? response.mapString()
                    print("schedule data: \(String(describing: string))")
                    
                    let json = try? response.mapJSON()
                    print("schedule data json: \(String(describing: json))")
                    
                    let scheduleData: T = try! response.map(T.self, atKeyPath: "schedule")
                    print("schedule data: \(String(describing: scheduleData))")
                    
                    reslove(scheduleData)
                case .failure(let error):
                    print("schedule data error: \(error)")
                    reject(error)
                }
            }
        }
    }
}

