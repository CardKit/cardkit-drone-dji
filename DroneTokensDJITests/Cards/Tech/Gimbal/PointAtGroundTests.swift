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

class PointAtGroundTests: BaseGimbalCardTests {
    func testPointAtGroundCard() {
        let myExpectation = expectation(description: "testPointAtGroundCard expectation")
        
        guard let gimbal = self.gimbal else {
            XCTFail("Could not find gimbal hardware")
            return
        }
        
        DispatchQueue.global(qos: .default).async {
            do {
                // setup PointAtFront card
                let pointAtGround = PointAtGround(with: DroneCardKit.Action.Tech.Gimbal.PointAtGround.makeCard())
                
                // bind input and token slots
                let tokenBindings: [String: ExecutableToken] = ["Gimbal": gimbal]
                pointAtGround.setup(inputBindings: [:], tokenBindings: tokenBindings)
                
                // execute
                pointAtGround.main()
                
                if let djiError = pointAtGround.errors.first {
                    throw djiError
                }
            } catch let error {
                XCTFail("\(error)")
            }
            
            myExpectation.fulfill()
        }
        
        waitForExpectations(timeout: expectationTimeout) { error in
            if let error = error {
                XCTFail("testPointAtGroundCard error: \(error)")
            }
        }
    }    
}
