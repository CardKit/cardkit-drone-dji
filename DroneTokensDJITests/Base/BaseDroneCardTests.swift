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

class BaseDroneCardTests: BaseHardwareTokenTest {
    var droneTokenCard: TokenCard = DroneCardKit.Token.Drone.makeCard()
    
    var drone: ExecutableToken?
    
    override func setUp() {
        super.setUp()
        
        runLoop { self.aircraft != nil }
        
        guard let aircraft = self.aircraft else {
            // because these tests are hardware tests and are part of continuous integration on build server, they should not fail if there is no hardware.  Instead, we assert that there is not hardware.
            XCTAssertNil(self.aircraft, "NO AIRCRAFT HARDWARE")
            return
        }
        
        self.drone = DJIDroneToken(with: droneTokenCard, for: aircraft)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
}
