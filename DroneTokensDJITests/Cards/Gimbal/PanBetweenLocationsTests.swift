//
//  PanBetweenLocationsTests.swift
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

class PanBetweenLocationsTests: BaseGimbalCardTests {
    func testPanBetweenLocationsCard() {
        let myExpectation = expectation(description: "testPanBetweenLocationsCard expectation")
        
        guard let drone = drone, let gimbal = gimbal else {
            XCTFail("Could not find drone and/or gimbal hardware")
            return
        }
        
        DispatchQueue.global(qos: .default).async {
            do {
                // determine location to point at
                let flyToLocation = DCKCoordinate2D(latitude: 23.00099, longitude: 113.9599)
                let startLocation = DCKCoordinate3D(latitude: 23.004897, longitude: 113.955945, altitude: DCKRelativeAltitude(metersAboveGroundAtTakeoff: 100))
                let endLocation = DCKCoordinate3D(latitude: 23.006654, longitude: 113.962990, altitude: DCKRelativeAltitude(metersAboveGroundAtTakeoff: 0))
                
                // setup PointInDirection card
                let panBetweenLocations = PanBetweenLocations(with: DroneCardKit.Action.Tech.Gimbal.PanBetweenLocations.makeCard())
                
                //take off
                if let droneToken = drone as? DroneToken {
                    try droneToken.fly(to: flyToLocation, atAltitude: DCKRelativeAltitude(metersAboveGroundAtTakeoff: 100))
                } else {
                    XCTFail("Could not cast `drone` as DroneToken.")
                }
                
                // bind input and token slots
                guard let droneTokenSlot = panBetweenLocations.actionCard.tokenSlots.slot(named: "DroneTelemetry"),
                    let gimbalTokenSlot = panBetweenLocations.actionCard.tokenSlots.slot(named: "Gimbal"),
                    let inputStartLocationTokenSlot = panBetweenLocations.actionCard.inputSlots.slot(named: "StartLocation"),
                    let inputEndLocationTokenSlot = panBetweenLocations.actionCard.inputSlots.slot(named: "EndLocation")  else {
                        XCTFail("could not find the right token/input slots")
                        myExpectation.fulfill()
                        return
                }
                
                let inputBindings = [inputStartLocationTokenSlot: InputDataBinding.bound(startLocation.toJSON()),
                                     inputEndLocationTokenSlot: InputDataBinding.bound(endLocation.toJSON())]
                let tokenBindings = [droneTokenSlot: drone, gimbalTokenSlot: gimbal]
                panBetweenLocations.setup(inputBindings, tokens: tokenBindings)
                
                // execute
                panBetweenLocations.main()
                
                if let djiError = panBetweenLocations.error {
                    throw djiError
                }
                
                
            } catch {
                XCTFail("\(error)")
            }
            
            myExpectation.fulfill()
        }
        
        waitForExpectations(timeout: expectationTimeout) { error in
            if let error = error {
                XCTFail("testPanBetweenLocationsCard error: \(error)")
            }
        }
    }
    
}
