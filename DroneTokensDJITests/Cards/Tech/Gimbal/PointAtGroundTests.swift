//
//  PointAtGroundTests.swift
//  DroneTokensDJI
//
//  Created by ismails on 2/16/17.
//  Copyright © 2017 IBM. All rights reserved.
//

@testable import DroneTokensDJI
@testable import DroneCardKit
@testable import CardKitRuntime
@testable import CardKit

import XCTest

import DJISDK

class PointAtGroundTests: BaseGimbalCardTests {
    func testPointAtGroundCard() {
        let myExpectation = expectation(description: "testPointAtGroundCard expectation")
        
        guard let gimbal = gimbal else {
            XCTFail("Could not find gimbal hardware")
            return
        }
        
        DispatchQueue.global(qos: .default).async {
            do {
                // setup PointAtFront card
                let pointAtGround = PointAtGround(with: DroneCardKit.Action.Tech.Gimbal.PointAtGround.makeCard())
                
                // bind input and token slots
                guard let gimbalTokenSlot = pointAtGround.actionCard.tokenSlots.slot(named: "Gimbal") else {
                    XCTFail("could not find the right token/input slots")
                    myExpectation.fulfill()
                    return
                }
                
                let tokenBindings = [gimbalTokenSlot: gimbal]
                pointAtGround.setup(inputBindings: [:], tokenBindings: tokenBindings)
                
                // execute
                pointAtGround.main()
                
                if let djiError = pointAtGround.errors.first {
                    throw djiError
                }
            } catch {
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
