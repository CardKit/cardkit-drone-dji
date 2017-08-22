//
//  PointAtGroundTests.swift
//  DroneTokensDJI
//
//  Created by ismails on 2/16/17.
//  Copyright © 2017 IBM. All rights reserved.
//

import XCTest

@testable import CardKit
@testable import CardKitRuntime
@testable import DroneCardKit
@testable import DroneTokensDJI

import DJISDK

class PointAtGroundTests: BaseGimbalCardTests {
    func testPointAtGroundCard() {
        let myExpectation = expectation(description: "testPointAtGroundCard expectation")
        
        guard let gimbal = self.gimbal else {
            XCTFail("Could not find gimbal hardware")
            return
        }
        
        DispatchQueue.global(qos: .default).async {
            do {
                // setup PointAtFront card
                let pointAtGround = PointAtGround(with: DroneCardKit.Action.Tech.Gimbal.PointAtGround.makeCard())
                
                // bind input and token slots
                let tokenBindings: [String: ExecutableToken] = ["Gimbal": gimbal]
                pointAtGround.setup(inputBindings: [:], tokenBindings: tokenBindings)
                
                // execute
                pointAtGround.main()
                
                if let djiError = pointAtGround.errors.first {
                    throw djiError
                }
            } catch let error {
                XCTFail("\(error)")
            }
            
            myExpectation.fulfill()
        }
        
        waitForExpectations(timeout: expectationTimeout) { error in
            if let error = error {
                XCTFail("testPointAtGroundCard error: \(error)")
            }
        }
    }    
}
