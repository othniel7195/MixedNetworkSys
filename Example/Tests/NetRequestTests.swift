//
//  NetRequestTest.swift
//  MixedNetworkSys_Tests
//
//  Created by jimmy on 2021/8/26.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import XCTest
import MixedNetworkSys

class NetRequestTests: XCTestCase {

    override func setUp() {
        super.setUp()
        
    }
   
    func test001LoginPost() {
        let expectation = XCTestExpectation(description: "login result")
        let provider = NetworkProvider(configuration: .init(useHTTPDNS: false), hosts: ["sobe-api-dev.shuinfo.com"])
        let login = ApiTest.login
        provider.request(login) { result in
            switch result {
            case .success(let response):
                let loginData = try? response.map(AccountLogin.self)
                print("login data: \(String(describing: loginData))")
                XCTAssertNotNil(loginData)
            case .failure(let error):
                XCTAssertTrue(false, "login failed:\(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }
    
    func test002OperatingStatusGet() {
        let expectation = XCTestExpectation(description: "get open time result")
        let auth1 = AccessTokenPlugin(tokenClosure: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY2NvdW50IjoyNTAwMDksImV4cCI6MTYzMDgzMzIxMSwiaWF0IjoxNjI5OTY5MjExLCJpc3MiOiJodHRwczovL3d3dy5zaHVpbmZvLmNvbSIsInBvcy1hY2NvdW50IjoyNTAwMDksInBvcy1kZXZpY2UiOiIiLCJwb3Mtc3RvcmUiOiI2MGY2NzcxYjgwYmQxNWUyMjZkYzQ0YjciLCJ0ZW5hbnQiOjQwMDAzfQ.Y_YahDeqh3IfPxWrf6-Ek9hgwEJ9wMLp4Lxp4JW3AQE")
        
        //let auth2 = AccessTokenPlugin(tokenClosure: "")
        
        let provider = NetworkProvider(configuration: .init(useHTTPDNS: false), plugins: [auth1], hosts: ["sobe-api-dev.shuinfo.com"])
        let openTime = ApiTest.openHours(id: "")
        provider.request(openTime) { result in
            switch result {
            case .success(let response):
                let string = try? response.mapString()
                print("schedule data: \(String(describing: string))")
                
                let json = try? response.mapJSON()
                print("schedule data json: \(String(describing: json))")
                
                do {
                    let scheduleData = try response.map(Schedule.self, atKeyPath: "schedule")
                    print("Schedule data: \(String(describing: scheduleData.opening_time))")
                    XCTAssertNotNil(scheduleData)
                } catch {
                    print("Schedule data error: \(error)")
                    XCTAssertTrue(false, "scheduleData parse error:\(error)")
                }
                
                
            case .failure(let error):
                XCTAssertTrue(false, "open time failed:\(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
