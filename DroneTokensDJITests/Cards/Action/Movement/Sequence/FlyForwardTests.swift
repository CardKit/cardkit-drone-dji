//
//  FlyForwardTests.swift
//  DroneTokensDJI
//
//  Created by ismails on 2/23/17.
//  Copyright © 2017 IBM. All rights reserved.
//

import XCTest

@testable import CardKit
@testable import CardKitRuntime
@testable import DroneCardKit
@testable import DroneTokensDJI

import DJISDK

class FlyForwardTests: BaseDroneCardTests {
    func testFlyForwardCard() {
        let myExpectation = expectation(description: "testFlyForwardCard expectation")
        
        guard let drone = self.drone else {
            XCTFail("could not find drone hardware")
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
                let inputBindings: [String: Codable] = ["Distance": distance]
                let tokenBindings: [String: ExecutableToken] = ["Drone": drone]
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
