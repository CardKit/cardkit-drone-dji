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
        
        guard let gimbalHardware = self.aircraft?.gimbal else {
            XCTFail("Gimbal does not exist")
            return
        }
        
        
        self.gimbal = DJIGimbalToken(with: DroneCardKit.Token.Gimbal.makeCard(), for: gimbalHardware)
    
    }
    
    func testPitch() {
        var completed = false
        
        
        self.gimbal?.rotate(yaw: DCKAngle(degrees: 0), pitch: DCKAngle(degrees: 90), roll: DCKAngle(degrees: 0), relativeToDrone: false, withinTimeInSeconds: 1, completionHandler: { (error) in
            if let error = error {
                XCTFail("could not update the pitch of the gimbal. error: \(error)")
            }
            
            completed = true
        })
        
        while !completed {
            RunLoop.current.run(mode: .defaultRunLoopMode, before: Date.distantFuture)
        }
    }
    
    func testReset() {
        var completed = false
        
        self.gimbal?.reset(completionHandler: { (error) in
            if let error = error {
                XCTFail("could not reset the gimbal. error: \(error)")
            }
            
            completed = true
        })
        
        while !completed {
            RunLoop.current.run(mode: .defaultRunLoopMode, before: Date.distantFuture)
        }
    }
}
