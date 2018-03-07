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

class PointInDirectionTests: BaseGimbalCardTests {
    func testPointInDirectionCard() {
        let myExpectation = expectation(description: "testPointInDirectionCard expectation")
        
        guard let telemetry = self.telemetry, let gimbal = self.gimbal else {
            XCTFail("Could not find drone and/or gimbal hardware")
            return
        }
        
        DispatchQueue.global(qos: .default).async {
            do {
                // determine location to point at
                let cardinalDirection = DCKAngle(degrees: 90) // this is East. See CardinalDirection
                
                // setup PointInDirection card
                let pointInDirection = PointInDirection(with: DroneCardKit.Action.Tech.Gimbal.PointInDirection.makeCard())
                
                // bind input and token slots
                let inputBindings: [String: Codable] = ["CardinalDirection": cardinalDirection]
                let tokenBindings: [String: ExecutableToken] = ["Telemetry": telemetry, "Gimbal": gimbal]
                pointInDirection.setup(inputBindings: inputBindings, tokenBindings: tokenBindings)
                
                // execute
                pointInDirection.main()
                
                if let djiError = pointInDirection.errors.first {
                    throw djiError
                }
            } catch {
                XCTFail("\(error)")
            }
            
            myExpectation.fulfill()
        }
        
        waitForExpectations(timeout: self.expectationTimeout) { error in
            if let error = error {
                XCTFail("testPointInDirectionCard error: \(error)")
            }
        }
    }
    
}
