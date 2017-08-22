//
//  PanBetweenLocationsTests.swift
//  DroneTokensDJI
//
//  Created by ismails on 2/16/17.
//  Copyright © 2017 IBM. All rights reserved.
//

import XCTest

@testable import CardKit
@testable import CardKitRuntime
@testable import DroneCardKit
@testable import DroneTokensDJI

import DJISDK

class PanBetweenLocationsTests: BaseGimbalCardTests {
    func testPanBetweenLocationsCard() {
        let myExpectation = expectation(description: "testPanBetweenLocationsCard expectation")
        
        guard let telemetry = self.telemetry, let gimbal = gimbal else {
            XCTFail("Could not find telemetry and/or gimbal hardware")
            return
        }
        
        DispatchQueue.global(qos: .default).async {
            do {
                // determine location to point at
                let startLocation = DCKCoordinate3D(latitude: 23.004897, longitude: 113.955945, altitude: DCKRelativeAltitude(metersAboveGroundAtTakeoff: 100))
                let endLocation = DCKCoordinate3D(latitude: 23.006654, longitude: 113.962990, altitude: DCKRelativeAltitude(metersAboveGroundAtTakeoff: 0))
                
                // setup PanBetweenLocations card
                let panBetweenLocations = PanBetweenLocations(with: DroneCardKit.Action.Tech.Gimbal.PanBetweenLocations.makeCard())
                
                // bind input and token slots
                let inputBindings: [String: Codable] = [
                    "StartLocation": startLocation,
                    "EndLocation": endLocation
                ]
                let tokenBindings = ["Telemetry": telemetry, "Gimbal": gimbal]
                panBetweenLocations.setup(inputBindings: inputBindings, tokenBindings: tokenBindings)
                
                // execute
                panBetweenLocations.main()
                
                if let djiError = panBetweenLocations.errors.first {
                    throw djiError
                }
            } catch {
                XCTFail("\(error)")
            }
            
            myExpectation.fulfill()
        }
        
        waitForExpectations(timeout: self.expectationTimeout) { error in
            if let error = error {
                XCTFail("testPanBetweenLocationsCard error: \(error)")
            }
        }
    }
}
