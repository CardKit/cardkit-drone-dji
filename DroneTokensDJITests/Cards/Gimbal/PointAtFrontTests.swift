//
//  PointAtFrontTests.swift
//  DroneTokensDJI
//
//  Created by ismails on 2/9/17.
//  Copyright © 2017 IBM. All rights reserved.
//

@testable import DroneTokensDJI
@testable import DroneCardKit
@testable import CardKitRuntime
@testable import CardKit

import XCTest

import DJISDK

class PointAtFrontTests: BaseGimbalCardTests {    
    func testPointAtFrontCard() {
        let myExpectation = expectation(description: "testPointAtFrontCard expectation")
        
        guard let gimbal = gimbal else {
            XCTFail("Could not find gimbal hardware")
            return
        }
        
        DispatchQueue.global(qos: .default).async {
            do {
                // setup PointAtFront card
                let pointAtFront = PointAtFront(with: DroneCardKit.Action.Tech.Gimbal.PointAtFront.makeCard())
                
                // bind input and token slots
                guard let gimbalTokenSlot = pointAtFront.actionCard.tokenSlots.slot(named: "Gimbal") else {
                    XCTFail("could not find the right token/input slots")
                    myExpectation.fulfill()
                    return
                }
                
                let tokenBindings = [gimbalTokenSlot: gimbal]
                pointAtFront.setup([:], tokens: tokenBindings)
                
                // execute
                pointAtFront.main()
                
                if let djiError = pointAtFront.error {
                    throw djiError
                }
            } catch {
                XCTFail("\(error)")
            }
            
            myExpectation.fulfill()
        }
        
        waitForExpectations(timeout: expectationTimeout) { error in
            if let error = error {
                XCTFail("testPointAtFrontCard error: \(error)")
            }
        }
    }
    
}

