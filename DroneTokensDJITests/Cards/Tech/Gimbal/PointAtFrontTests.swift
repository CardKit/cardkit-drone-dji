//
//  PointAtFrontTests.swift
//  DroneTokensDJI
//
//  Created by ismails on 2/9/17.
//  Copyright © 2017 IBM. All rights reserved.
//

import XCTest

@testable import CardKit
@testable import CardKitRuntime
@testable import DroneCardKit
@testable import DroneTokensDJI

import DJISDK

class PointAtFrontTests: BaseGimbalCardTests {    
    func testPointAtFrontCard() {
        let myExpectation = expectation(description: "testPointAtFrontCard expectation")
        
        guard let gimbal = self.gimbal else {
            XCTFail("Could not find gimbal hardware")
            return
        }
        
        DispatchQueue.global(qos: .default).async {
            do {
                // setup PointAtFront card
                let pointAtFront = PointAtFront(with: DroneCardKit.Action.Tech.Gimbal.PointAtFront.makeCard())
                
                // bind input and token slots
                let tokenBindings: [String: ExecutableToken] = ["Gimbal": gimbal]
                pointAtFront.setup(inputBindings: [:], tokenBindings: tokenBindings)
                
                // execute
                pointAtFront.main()
                
                if let djiError = pointAtFront.errors.first {
                    throw djiError
                }
            } catch {
                XCTFail("\(error)")
            }
            
            myExpectation.fulfill()
        }
        
        waitForExpectations(timeout: self.expectationTimeout) { error in
            if let error = error {
                XCTFail("testPointAtFrontCard error: \(error)")
            }
        }
    }
    
}
