//
//  BaseGimbalCardTests
//  DroneTokensDJI
//
//  Created by ismails on 2/9/17.
//  Copyright © 2017 IBM. All rights reserved.
//

@testable import DroneTokensDJI
@testable import DroneCardKit
@testable import CardKitRuntime
@testable import CardKit

import XCTest

import DJISDK

class BaseGimbalCardTests: DJIHardwareTokenTest {
    var droneTelemetryTokenCard: TokenCard = DroneCardKit.Token.Telemetry.makeCard()
    var gimbalTokenCard: TokenCard = DroneCardKit.Token.Gimbal.makeCard()
    
    var gimbal: ExecutableToken?
    var drone: ExecutableToken?
    let expectationTimeout: TimeInterval = 1000
    
    override func setUp() {
        super.setUp()
        
        runLoop { self.aircraft?.gimbal != nil }
        
        guard let aircraft = self.aircraft else {
            XCTFail("Drone does not exist")
            return
        }
        
        self.drone = DJIDroneToken(with: droneTelemetryTokenCard, for: aircraft)
        
        guard let gimbalHardware = aircraft.gimbal else {
            XCTFail("Gimbal does not exist")
            return
        }
        
        self.gimbal = DJIGimbalToken(with: gimbalTokenCard, for: gimbalHardware)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
}
