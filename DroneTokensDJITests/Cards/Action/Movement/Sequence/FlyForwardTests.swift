//
//  FlyForwardTests.swift
//  DroneTokensDJI
//
//  Created by ismails on 2/23/17.
//  Copyright © 2017 IBM. All rights reserved.
//

@testable import DroneTokensDJI
@testable import DroneCardKit
@testable import CardKitRuntime
@testable import CardKit

import XCTest

import DJISDK

class FlyForwardTests: BaseDroneTokenTests {
    // when  ideally it would be good to test fly forward when facing different angles (various yaw angles)
    // however we are not able to update our yaw yet.. therefore the yaw will have 
    // to be manually updated for now with the remote controller in the simulator
    // this test will make the drone take off and hover and fly forward in the direction 
    // that it is already facing
    func testFlyForwardCard() {
        let myExpectation = expectation(description: "testFlyForwardCard expectation")
        
        guard let drone = drone else {
            XCTFail("Could not find drone and/or gimbal hardware")
            return
        }
        
        DispatchQueue.global(qos: .default).async {
            do {
                var originalLocation = DCKCoordinate2D(latitude: 23.00099, longitude: 113.9599)
                
                // create other inputs
                let distance = DCKDistance(meters: 10.0)
                
                // takeoff and hover at 10m
                if let droneToken = drone as? DroneToken {
                    if let droneLocation = droneToken.currentLocation {
                        originalLocation = droneLocation
                    }
                    
                    try droneToken.fly(to: originalLocation)
                } else {
                    XCTFail("Could not cast `drone` as DroneToken.")
                }
                
                // setup card
                let flyForward = FlyForward(with: DroneCardKit.Action.Movement.Simple.FlyForward.makeCard())
                
                // bind input and token slots
                guard let droneTokenSlot = flyForward.actionCard.tokenSlots.slot(named: "Drone"),
                    let distanceSlot = flyForward.actionCard.inputSlots.slot(named: "Distance") else {
                        XCTFail("could not find the right token/input slots")
                        myExpectation.fulfill()
                        return
                }
                
                let inputBindings: [InputSlot: DataBinding] = [distanceSlot: .bound(distance.toJSON())]
                let tokenBindings = [droneTokenSlot: drone]
                flyForward.setup(inputBindings: inputBindings, tokenBindings: tokenBindings)
                
                // execute
                flyForward.main()
                
                if let djiError = flyForward.errors.first {
                    throw djiError
                }
            } catch {
                XCTFail("\(error)")
            }
            
            myExpectation.fulfill()
        }
        
        waitForExpectations(timeout: expectationTimeout) { error in
            if let error = error {
                XCTFail("testFlyForwardCard error: \(error)")
            }
        }
    }
}
