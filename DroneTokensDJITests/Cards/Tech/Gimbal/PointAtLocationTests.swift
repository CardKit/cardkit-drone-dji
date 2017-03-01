//
//  PointAtLocationTests.swift
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

class PointAtLocationTests: BaseGimbalCardTests {
    func testPointAtLocationCard() {
        let myExpectation = expectation(description: "testPointAtLocationCard expectation")
        
        guard let drone = drone, let gimbal = gimbal else {
            XCTFail("Could not find drone and/or gimbal hardware")
            return
        }
        
        DispatchQueue.global(qos: .default).async {
            do {
                // determine location to point at
                let originalLocation = DCKCoordinate2D(latitude: 23.00099, longitude: 113.9599)
                let newLocation = DCKCoordinate2D(latitude: 23.00199, longitude: 113.9600)
                let locationToPointAt = DCKCoordinate3D(latitude: newLocation.latitude, longitude: newLocation.longitude, altitude: DCKRelativeAltitude(metersAboveGroundAtTakeoff: 0.0))
                
                // takeoff and hover at 10m
                if let droneToken = drone as? DroneToken {
                    try droneToken.fly(to: originalLocation, atAltitude: DCKRelativeAltitude(metersAboveGroundAtTakeoff: 100))
                } else {
                    XCTFail("Could not cast `drone` as DroneToken.")
                }
                
                // setup PointAtLocation card
                let pointAtLocation = PointAtLocation(with: DroneCardKit.Action.Tech.Gimbal.PointAtLocation.makeCard())
                
                // bind input and token slots
                guard let droneTokenSlot = pointAtLocation.actionCard.tokenSlots.slot(named: "DroneTelemetry"),
                    let gimbalTokenSlot = pointAtLocation.actionCard.tokenSlots.slot(named: "Gimbal"),
                    let inputLocationTokenSlot = pointAtLocation.actionCard.inputSlots.slot(named: "Location") else {
                        XCTFail("could not find the right token/input slots")
                        myExpectation.fulfill()
                        return
                }
                
                let inputBindings = [inputLocationTokenSlot: DataBinding.bound(locationToPointAt.toJSON())]
                let tokenBindings = [droneTokenSlot: drone, gimbalTokenSlot: gimbal]
                pointAtLocation.setup(inputBindings: inputBindings, tokenBindings: tokenBindings)
                
                // execute
                pointAtLocation.main()
                
                if let djiError = pointAtLocation.errors.first {
                    throw djiError
                }
            } catch {
                XCTFail("\(error)")
            }
            
            myExpectation.fulfill()
        }
        
        waitForExpectations(timeout: expectationTimeout) { error in
            if let error = error {
                XCTFail("testPointAtLocationCard error: \(error)")
            }
        }
    }
    
}
