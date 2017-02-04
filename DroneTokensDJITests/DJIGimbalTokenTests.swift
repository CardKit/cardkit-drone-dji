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
    
    /// Test pitch control of drone using velocity
    func testPitchUsingVelocity() {
        var completed = false
        
        let angularVelocity = DCKAngularVelocity(degreesPerSecond: 5)
        
        self.gimbal?.rotate(pitch: angularVelocity, forTimeInSeconds: 10, completionHandler: { (error) in
            if let error = error {
                XCTFail("could not update the pitch of the gimbal. error: \(error)")
            }
            
            completed = true
        })
        
        runLoop { completed }
    }
    
    
    /// Test pitch control of drone
    func testPitchUsingAbsoluteAngle() {
        var completed = false
        let zeroAngle = DCKAngle(degrees: 0)
        
        //test pitch absolute
        self.gimbal?.rotate(yaw: zeroAngle, pitch: DCKAngle(degrees: 70), roll: zeroAngle, relativeToDrone: false, withinTimeInSeconds: 10, completionHandler: { (error) in
            if let error = error {
                XCTFail("could not update the pitch of the gimbal. error: \(error)")
            }
            
            completed = true
        })
        
        runLoop { completed }
    }
    
    func testPitchUsingRelativeAngle() {
        var completed = false
        let zeroAngle = DCKAngle(degrees: 0)
        
        self.gimbal?.rotate(yaw: zeroAngle, pitch: DCKAngle(degrees: -20), roll: zeroAngle, relativeToDrone: true, withinTimeInSeconds: 1, completionHandler: { (error) in
            if let error = error {
                XCTFail("could not update the pitch of the gimbal. error: \(error)")
            }
            
            completed = true
        })
        
        runLoop { completed }
    }
    
    func testCalibrate() {
        var completed = false
        
        self.gimbal?.calibrate(completionHandler: { (error) in
            if let error = error {
                XCTFail("could not reset the gimbal. error: \(error)")
            }
            
            completed = true
        })
        
        runLoop { completed }
    }
    
    func testReset() {
        var completed = false
        
        self.gimbal?.reset(completionHandler: { (error) in
            if let error = error {
                XCTFail("could not reset the gimbal. error: \(error)")
            }
            
            completed = true
        })
        
        runLoop { completed }
    }
}
