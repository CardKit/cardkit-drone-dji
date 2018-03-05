//
//  DJIGimbalTokenTests.swift
//  DroneTokensDJI
//
//  Created by ismails on 2/3/17.
//  Copyright © 2017 IBM. All rights reserved.
//

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
                try self.gimbal?.rotate(yaw: zeroAngle, pitch: DCKAngle(degrees: 70), roll: zeroAngle, relativeToDrone: false, withinTimeInSeconds: 10)
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
                try self.gimbal?.rotate(yaw: zeroAngle, pitch: DCKAngle(degrees: -270), roll: zeroAngle, relativeToDrone: true, withinTimeInSeconds: 1)
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
