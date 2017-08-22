//
//  BaseGimbalCardTests
//  DroneTokensDJI
//
//  Created by ismails on 2/9/17.
//  Copyright © 2017 IBM. All rights reserved.
//

import XCTest

@testable import CardKit
@testable import CardKitRuntime
@testable import DroneCardKit
@testable import DroneTokensDJI

import DJISDK

class BaseGimbalCardTests: BaseHardwareTokenTest {
    var telemetryTokenCard: TokenCard = DroneCardKit.Token.Telemetry.makeCard()
    var gimbalTokenCard: TokenCard = DroneCardKit.Token.Gimbal.makeCard()
    
    var gimbal: ExecutableToken?
    var telemetry: ExecutableToken?
    
    override func setUp() {
        super.setUp()
        
        runLoop { self.aircraft?.gimbal != nil }
        
        guard let aircraft = self.aircraft else {
            XCTFail("Drone does not exist")
            return
        }
        
        self.telemetry = DJIDroneToken(with: telemetryTokenCard, for: aircraft)
        
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
