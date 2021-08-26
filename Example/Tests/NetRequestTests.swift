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
    override func setUp() {
        super.setUp()
        provider = NetworkProvider(configuration: .init(useHTTPDNS: false), hosts: ["www"])
        provider.
        
    }
   

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
