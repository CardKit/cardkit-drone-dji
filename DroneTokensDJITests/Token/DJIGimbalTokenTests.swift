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
@testable import DroneCardKit
@testable import DroneTokensDJI

import DJISDK

class DJIGimbalTokenTests: BaseHardwareTokenTest {
    var gimbal: GimbalToken?
    
    override func setUp() {
        super.setUp()
        
        // Sometimes gimbal is nil.  Keep trying until it isn't.
        runLoop { self.aircraft?.gimbal != nil }
        
        guard let gimbalHardware = self.aircraft?.gimbal else {
            // because these tests are hardware tests and are part of continuous integration on build server, they should not fail if there is no hardware.  Instead, we assert that there is not hardware.
            XCTAssertNil(self.aircraft?.gimbal, "NO GIMBAL HARDWARE")
            return
        }
        
        self.gimbal = DJIGimbalToken(with: DroneCardKit.Token.Gimbal.makeCard(), for: gimbalHardware)
        XCTAssertNotNil(self.gimbal, "gimbal token card could not be created")
    }
    
    func testDownwardOrient() {
        let myExpectation = expectation(description: "testDownwardOrient expectation")
        
        DispatchQueue.global(qos: .default).async {
            do {
                try self.gimbal?.orient(to: .facingDownward)
            } catch {
                XCTFail("could not update the pitch of the gimbal. error: \(error)")
            }
            
            myExpectation.fulfill()
        }
        
        waitForExpectations(timeout: expectationTimeout) { error in
            if let error = error {
                XCTFail("testDownwardOrient error: \(error)")
            }
        }
    }
    
    func testForwardOrient() {
        let myExpectation = expectation(description: "testForwardOrient expectation")
        
        DispatchQueue.global(qos: .default).async {
            do {
                try self.gimbal?.orient(to: .facingForward)
            } catch {
                XCTFail("could not update the pitch of the gimbal. error: \(error)")
            }
            
            myExpectation.fulfill()
        }
        
        waitForExpectations(timeout: expectationTimeout) { error in
            if let error = error {
                XCTFail("testForwardOrient error: \(error)")
            }
        }
    }
    
    func testPitchUsingAbsoluteAngle() {
        let myExpectation = expectation(description: "testPitchUsingAbsoluteAngle expectation")
        let zeroAngle = DCKAngle(degrees: 0)
        
        DispatchQueue.global(qos: .default).async {
            do {
                try self.gimbal?.rotate(yaw: zeroAngle, pitch: DCKAngle(degrees: 70), roll: zeroAngle, relative: false, withinTimeInSeconds: 10)
            } catch {
                XCTFail("could not update the pitch of the gimbal. error: \(error)")
            }
            
            myExpectation.fulfill()
        }
        
        waitForExpectations(timeout: expectationTimeout) { error in
            if let error = error {
                XCTFail("testPitchUsingAbsoluteAngle error: \(error)")
            }
        }
    }
    
    func testPitchUsingRelativeAngle() {
        let myExpectation = expectation(description: "testPitchUsingRelativeAngle expectation")
        let zeroAngle = DCKAngle(degrees: 0)
        
        DispatchQueue.global(qos: .default).async {
            do {
                try self.gimbal?.rotate(yaw: zeroAngle, pitch: DCKAngle(degrees: -270), roll: zeroAngle, relative: true, withinTimeInSeconds: 1)
            } catch {
                XCTFail("could not update the pitch of the gimbal. error: \(error)")
            }
            
            myExpectation.fulfill()
        }
        
        waitForExpectations(timeout: expectationTimeout) { error in
            if let error = error {
                XCTFail("testPitchUsingRelativeAngle error: \(error)")
            }
        }
    }
    
    func testCalibrate() {
        let myExpectation = expectation(description: "testCalibrate expectation")
        
        DispatchQueue.global(qos: .default).async {
            do {
                try self.gimbal?.calibrate()
            } catch {
                XCTFail("could not calibrate the gimbal. error: \(error)")
            }
            
            myExpectation.fulfill()
        }
        
        waitForExpectations(timeout: expectationTimeout) { error in
            if let error = error {
                XCTFail("testCalibrate error: \(error)")
            }
        }
    }
    
    func testReset() {
        let myExpectation = expectation(description: "testReset expectation")
        
        DispatchQueue.global(qos: .default).async {
            do {
                try self.gimbal?.reset()
            } catch {
                XCTFail("could not reset the gimbal. error: \(error)")
            }
            
            myExpectation.fulfill()
        }
        
        waitForExpectations(timeout: expectationTimeout) { error in
            if let error = error {
                XCTFail("testReset error: \(error)")
            }
        }
    }
}
