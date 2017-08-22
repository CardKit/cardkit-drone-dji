//
//  PointAtLocationTests.swift
//  DroneTokensDJI
//
//  Created by ismails on 2/9/17.
//  Copyright © 2017 IBM. All rights reserved.
//

import XCTest

@testable import CardKit
@testable import CardKitRuntime
@testable import DroneCardKit
@testable import DroneTokensDJI

import DJISDK

class PointAtLocationTests: BaseGimbalCardTests {
    func testPointAtLocationCard() {
        let myExpectation = expectation(description: "testPointAtLocationCard expectation")
        
        guard let telemetry = self.telemetry, let gimbal = self.gimbal else {
            XCTFail("Could not find drone and/or gimbal hardware")
            return
        }
        
        DispatchQueue.global(qos: .default).async {
            do {
                // determine location to point at
                let locationToPointAt = DCKCoordinate3D(latitude: 23.00199, longitude: 113.9600, altitude: DCKRelativeAltitude(metersAboveGroundAtTakeoff: 0.0))
                
                // setup PointAtLocation card
                let pointAtLocation = PointAtLocation(with: DroneCardKit.Action.Tech.Gimbal.PointAtLocation.makeCard())
                
                // bind input and token slots
                let inputBindings: [String: Codable] = ["Location": locationToPointAt]
                let tokenBindings: [String: ExecutableToken] = ["Telemetry": telemetry, "Gimbal": gimbal]
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
        
        waitForExpectations(timeout: self.expectationTimeout) { error in
            if let error = error {
                XCTFail("testPointAtLocationCard error: \(error)")
            }
        }
    }
}
