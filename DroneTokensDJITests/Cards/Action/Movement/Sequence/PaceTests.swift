//
//  PaceTests.swift
//  DroneTokensDJI
//
//  Created by ismails on 2/17/17.
//  Copyright © 2017 IBM. All rights reserved.
//

import Foundation

@testable import DroneTokensDJI
@testable import DroneCardKit
@testable import CardKitRuntime
@testable import CardKit

import XCTest

import DJISDK

class PaceTests: BaseDroneTokenTests {
    func testPaceCard() {
        let myExpectation = expectation(description: "testPaceCard expectation")
        
        guard let drone = drone else {
            XCTFail("Could not find drone and/or gimbal hardware")
            return
        }
        
        DispatchQueue.global(qos: .default).async {
            do {
                let originalLocation = DCKCoordinate2D(latitude: 23.00099, longitude: 113.9599)
                
                // determine path to fly
                // https://www.google.com/maps/dir/23.00099,+113.9599/23.0013356,113.9594235/23.0015072,113.9602554/23.0009514,113.9602443/23.0010923,113.9599299/@23.001543,113.959468,18.95z/data=!4m10!4m9!1m3!2m2!1d113.9599!2d23.00099!1m0!1m0!1m0!1m0!3e2
                
                
                let locationsInPath: [DCKCoordinate2D] = [
                    DCKCoordinate2D(latitude: 23.0013356, longitude: 113.9594235),
                    DCKCoordinate2D(latitude: 23.0015072, longitude: 113.9602554),
                    DCKCoordinate2D(latitude: 23.0009514, longitude: 113.9602443),
                    DCKCoordinate2D(latitude: 23.0010923, longitude: 113.9599299)
                ]
                let path = DCKCoordinate2DPath(path: locationsInPath)
                
                // create other inputs
                let altitude = DCKRelativeAltitude(metersAboveGroundAtTakeoff: 20)
                let speed = DCKSpeed(metersPerSecond: 10)
                let duration = 5.0
                
                // takeoff and hover at 10m
                if let droneToken = drone as? DroneToken {
                    try droneToken.fly(to: originalLocation, atAltitude: DCKRelativeAltitude(metersAboveGroundAtTakeoff: 10))
                } else {
                    XCTFail("Could not cast `drone` as DroneToken.")
                }
                
                // setup card
                let paceCard = Pace(with: DroneCardKit.Action.Movement.Sequence.Pace.makeCard())
                
                // bind input and token slots
                guard let droneTokenSlot = paceCard.actionCard.tokenSlots.slot(named: "Drone"),
                    let pathSlot = paceCard.actionCard.inputSlots.slot(named: "Path"),
                    let speedSlot = paceCard.actionCard.inputSlots.slot(named: "Speed") ,
                    let durationSlot = paceCard.actionCard.inputSlots.slot(named: "Duration"),
                    let altitudeSlot = paceCard.actionCard.inputSlots.slot(named: "Altitude")  else {
                        XCTFail("could not find the right token/input slots")
                        myExpectation.fulfill()
                        return
                }
                
                let inputBindings: [InputSlot: InputDataBinding] = [
                    pathSlot: .bound(path.toJSON()),
                    speedSlot: .bound(speed.toJSON()),
                    durationSlot: .bound(duration.toJSON()),
                    altitudeSlot: .bound(altitude.toJSON())
                ]
                
                let tokenBindings = [droneTokenSlot: drone]
                paceCard.setup(inputBindings, tokens: tokenBindings)
                
                // execute
                paceCard.main()
                
                if let djiError = paceCard.error {
                    throw djiError
                }
            } catch {
                XCTFail("\(error)")
            }
            
            myExpectation.fulfill()
        }
        
        waitForExpectations(timeout: expectationTimeout) { error in
            if let error = error {
                XCTFail("testPaceCard error: \(error)")
            }
        }
        
    }
}
