//
//  PointInDirectionTests.swift
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
import Foundation

class PointInDirectionTests: BaseGimbalCardTests {
    func testPointInDirectionCard() {
        let myExpectation = expectation(description: "testPointInDirectionCard expectation")
        
        guard let drone = drone, let gimbal = gimbal else {
            XCTFail("Could not find drone and/or gimbal hardware")
            return
        }
        
        DispatchQueue.global(qos: .default).async {
            do {
                // determine location to point at
                let cardinalDirection = DCKAngle(degrees: 90) // this is East. See CardinalDirection
                
                // setup PointInDirection card
                let pointInDirection = PointInDirection(with: DroneCardKit.Action.Tech.Gimbal.PointInDirection.makeCard())
                
                //take off
                if let droneToken = drone as? DroneToken {
                    try droneToken.takeOff(at: DCKRelativeAltitude(metersAboveGroundAtTakeoff: 5))
                } else {
                    XCTFail("Could not cast `drone` as DroneToken.")
                }
                
                // bind input and token slots
                guard let droneTokenSlot = pointInDirection.actionCard.tokenSlots.slot(named: "DroneTelemetry"),
                    let gimbalTokenSlot = pointInDirection.actionCard.tokenSlots.slot(named: "Gimbal"),
                    let inputLocationTokenSlot = pointInDirection.actionCard.inputSlots.slot(named: "CardinalDirection") else {
                        XCTFail("could not find the right token/input slots")
                        myExpectation.fulfill()
                        return
                }
                
                let inputBindings = [inputLocationTokenSlot: InputDataBinding.bound(cardinalDirection.toJSON())]
                let tokenBindings = [droneTokenSlot: drone, gimbalTokenSlot: gimbal]
                pointInDirection.setup(inputBindings, tokens: tokenBindings)
                
                // execute
                pointInDirection.main()
                
                if let djiError = pointInDirection.error {
                    throw djiError
                }
                
                
            } catch {
                XCTFail("\(error)")
            }
            
            myExpectation.fulfill()
        }
        
        waitForExpectations(timeout: expectationTimeout) { error in
            if let error = error {
                XCTFail("testPointInDirectionCard error: \(error)")
            }
        }
    }
    
}
