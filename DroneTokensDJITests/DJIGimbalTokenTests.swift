//
//  DJIGimbalTokenTests.swift
//  DroneTokensDJI
//
//  Created by ismails on 2/3/17.
//  Copyright © 2017 IBM. All rights reserved.
//

import XCTest
@testable import DroneTokensDJI
import DroneCardKit
import DJISDK

class DJIGimbalTokenTests: DJIHardwareTokenTest {
    
    var gimbal: GimbalToken?
    let expectationTimeout: TimeInterval = 1000
    
    override func setUp() {
        super.setUp()
        
        runLoop { self.aircraft?.gimbal != nil }
        
        guard let gimbalHardware = self.aircraft?.gimbal else {
            XCTFail("Gimbal does not exist")
            return
        }
        
        self.gimbal = DJIGimbalToken(with: DroneCardKit.Token.Gimbal.makeCard(), for: gimbalHardware)
        
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
    
    /// Test pitch control of drone using velocity
    func testPitchUsingVelocity() {
        let myExpectation = expectation(description: "testPitchUsingVelocity expectation")
        let angularVelocity = DCKAngularVelocity(degreesPerSecond: 5)
        
        DispatchQueue.global(qos: .default).async {
            do {
                try self.gimbal?.rotate(pitch: angularVelocity, forTimeInSeconds: 5)
            } catch {
                XCTFail("could not update the pitch of the gimbal. error: \(error)")
            }
            
            myExpectation.fulfill()
        }
        
        waitForExpectations(timeout: expectationTimeout) { error in
            if let error = error {
                XCTFail("testPitchUsingVelocity error: \(error)")
            }
        }
    }
    
    
    /// Test pitch control of drone
    func testPitchUsingAbsoluteAngle() {
        let myExpectation = expectation(description: "testPitchUsingAbsoluteAngle expectation")
        let zeroAngle = DCKAngle(degrees: 0)
        
        DispatchQueue.global(qos: .default).async {
            do {
                //test pitch absolute
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
                try self.gimbal?.rotate(yaw: zeroAngle, pitch: DCKAngle(degrees: -20), roll: zeroAngle, relativeToDrone: true, withinTimeInSeconds: 1)
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
