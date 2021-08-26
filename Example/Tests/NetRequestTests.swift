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

    var provider: NetworkProvider!
    var loginData: AccountLogin?
    override func setUp() {
        super.setUp()
        provider = NetworkProvider(configuration: .init(useHTTPDNS: false), hosts: ["sobe-api-dev.shuinfo.com"])
    }
   
    func test001LoginPost() {
        let expectation = XCTestExpectation(description: "login result")
        let login = ApiTest.login
        provider.request(login) { result in
            switch result {
            case .success(let response):
                let loginData = try? response.map(AccountLogin.self)
                print("login data: \(String(describing: loginData))")
                self.loginData = loginData
                XCTAssertNotNil(loginData)
            case .failure(let error):
                XCTAssertTrue(false, "login failed:\(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }
    
    func test002OpenTimeGet() {
        let expectation = XCTestExpectation(description: "get open time result")
        let id = "60766378cb3e5c5d39ce2475"
        let openTime = ApiTest.openHours(id: id)
        provider.request(openTime) { result in
            switch result {
            case .success(let response):
                let scheduleData = try? response.map(Schedule.self)
                print("open time data: \(String(describing: scheduleData))")
                XCTAssertNotNil(scheduleData)
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
