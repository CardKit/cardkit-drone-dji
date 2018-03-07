/**
 * Copyright 2018 IBM Corp. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

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
