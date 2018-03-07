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

class PaceTests: BaseDroneCardTests {
    func testPaceCard() {
        let myExpectation = expectation(description: "testPaceCard expectation")
        
        guard let drone = self.drone else {
            XCTFail("could not find drone hardware")
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
                let inputBindings: [String: Codable] = [
                    "Path": path,
                    "Speed": speed,
                    "Duration": duration,
                    "Altitude": altitude
                ]
                
                let tokenBindings: [String: ExecutableToken] = ["Drone": drone]
                paceCard.setup(inputBindings: inputBindings, tokenBindings: tokenBindings)
                
                // execute
                paceCard.main()
                
                if let djiError = paceCard.errors.first {
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
