//
//  TestDJIGimbalToken.swift
//  DroneTokensDJITests
//
//  Created by jweisz on 1/31/17.
//  Copyright © 2017 IBM. All rights reserved.
//

import XCTest

@testable import CardKit
@testable import DroneCardKit
@testable import DroneTokensDJI
@testable import DJISDK

class TestDJIGimbalToken: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testDJIGimbalParams() {
        let gimbal: DJIGimbal = DJIGimbal()
        
        print("gimbal capabilities:")
        for (k, v) in gimbal.gimbalCapability {
            print("\(k): \(v)")
        }
    }
}
