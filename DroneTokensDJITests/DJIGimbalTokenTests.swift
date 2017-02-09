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
        var isCompleted = false
        
        DispatchQueue.global(qos: .default).async {
            do {
                try self.gimbal?.orient(to: .facingDownward)
            } catch {
                XCTFail("could not update the pitch of the gimbal. error: \(error)")
            }
            
            isCompleted = true
        }
        
        runLoop { isCompleted }
    }
    
    func testForwardOrient() {
        var isCompleted = false
        
        DispatchQueue.global(qos: .default).async {
            do {
                try self.gimbal?.orient(to: .facingForward)
            } catch {
                XCTFail("could not update the pitch of the gimbal. error: \(error)")
            }
            
            isCompleted = true
        }
        
        runLoop { isCompleted }
    }
    
    /// Test pitch control of drone using velocity
    func testPitchUsingVelocity() {
        var isCompleted = false
        let angularVelocity = DCKAngularVelocity(degreesPerSecond: 5)
        
        DispatchQueue.global(qos: .default).async {
            do {
                try self.gimbal?.rotate(pitch: angularVelocity, forTimeInSeconds: 5)
            } catch {
                XCTFail("could not update the pitch of the gimbal. error: \(error)")
            }
            
            isCompleted = true
        }
        
        runLoop { isCompleted }
    }
    
    
    /// Test pitch control of drone
    func testPitchUsingAbsoluteAngle() {
        var isCompleted = false
        let zeroAngle = DCKAngle(degrees: 0)
        
        DispatchQueue.global(qos: .default).async {
            do {
                //test pitch absolute
                try self.gimbal?.rotate(yaw: zeroAngle, pitch: DCKAngle(degrees: 70), roll: zeroAngle, relativeToDrone: false, withinTimeInSeconds: 10)
            } catch {
                XCTFail("could not update the pitch of the gimbal. error: \(error)")
            }
            
            isCompleted = true
        }
        
        runLoop { isCompleted }
    }
    
    func testPitchUsingRelativeAngle() {
        var isCompleted = false
        let zeroAngle = DCKAngle(degrees: 0)
        
        DispatchQueue.global(qos: .default).async {
            do {
                try self.gimbal?.rotate(yaw: zeroAngle, pitch: DCKAngle(degrees: -270), roll: zeroAngle, relativeToDrone: true, withinTimeInSeconds: 1)
            } catch {
                XCTFail("could not update the pitch of the gimbal. error: \(error)")
            }
            
            isCompleted = true
        }
        
        runLoop { isCompleted }
    }
    
    func testCalibrate() {
        var isCompleted = false
        
        DispatchQueue.global(qos: .default).async {
            do {
                try self.gimbal?.calibrate()
            } catch {
                XCTFail("could not calibrate the gimbal. error: \(error)")
            }
            
            isCompleted = true
        }
        
        runLoop { isCompleted }
    }
    
    func testReset() {
        var isCompleted = false
        
        DispatchQueue.global(qos: .default).async {
            do {
                try self.gimbal?.reset()
            } catch {
                XCTFail("could not reset the gimbal. error: \(error)")
            }
            
            isCompleted = true
        }
        
        runLoop { isCompleted }
    }
}
