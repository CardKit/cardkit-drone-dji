//
//  FlyPathTests.swift
//  DroneTokensDJI
//
//  Created by ismails on 2/17/17.
//  Copyright © 2017 IBM. All rights reserved.
//

@testable import DroneTokensDJI
@testable import DroneCardKit
@testable import CardKitRuntime
@testable import CardKit

import XCTest

import DJISDK

class FlyPathTests: BaseDroneTokenTests {
    func testFlyPathCard() {
        let myExpectation = expectation(description: "testFlyPathCard expectation")
        
        guard let drone = drone else {
            XCTFail("Could not find drone and/or gimbal hardware")
            return
        }
        
        DispatchQueue.global(qos: .default).async {
            do {
                let originalLocation = DCKCoordinate2D(latitude: 23.00099, longitude: 113.9599)
                
                // determine path to fly
                // https://www.google.com/maps/dir/23.00099,+113.9599/23.0023126,113.9584264/23.0032235,113.9601461/23.0019766,113.960492/23.0016405,113.9594352/@23.001785,113.9580413,18z/data=!3m1!4b1!4m10!4m9!1m3!2m2!1d113.9599!2d23.00099!1m0!1m0!1m0!1m0!3e2
             
                let locationsInPath: [DCKCoordinate2D] = [
                    DCKCoordinate2D(latitude: 23.0023126, longitude: 113.9584264),
                    DCKCoordinate2D(latitude: 23.0032235, longitude: 113.9601461),
                    DCKCoordinate2D(latitude: 23.0019766, longitude: 113.960492),
                    DCKCoordinate2D(latitude: 23.0016405, longitude: 113.9594352)
                ]
                let path = DCKCoordinate2DPath(path: locationsInPath)
                
                
                // takeoff and hover at 10m
                if let droneToken = drone as? DroneToken {
                    try droneToken.fly(to: originalLocation, atAltitude: DCKRelativeAltitude(metersAboveGroundAtTakeoff: 10))
                } else {
                    XCTFail("Could not cast `drone` as DroneToken.")
                }
                
                // setup card
                let flyPath = FlyPath(with: DroneCardKit.Action.Movement.Sequence.FlyPath.makeCard())
                
                // bind input and token slots
                guard let droneTokenSlot = flyPath.actionCard.tokenSlots.slot(named: "Drone"),
                    let pathSlot = flyPath.actionCard.inputSlots.slot(named: "Path") else {
                        XCTFail("could not find the right token/input slots")
                        myExpectation.fulfill()
                        return
                }
                
                let inputBindings = [pathSlot: InputDataBinding.bound(path.toJSON())]
                let tokenBindings = [droneTokenSlot: drone]
                flyPath.setup(inputBindings, tokens: tokenBindings)
                
                // execute
                flyPath.main()
                
                if let djiError = flyPath.error {
                    throw djiError
                }
            } catch {
                XCTFail("\(error)")
            }
            
            myExpectation.fulfill()
        }
        
        waitForExpectations(timeout: expectationTimeout) { error in
            if let error = error {
                XCTFail("testFlyPathCard error: \(error)")
            }
        }
        
    }
}
