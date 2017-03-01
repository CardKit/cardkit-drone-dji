//
//  BaseDroneTokenTests
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

class BaseDroneTokenTests: DJIHardwareTokenTest {
    var droneTelemetryTokenCard: TokenCard = DroneCardKit.Token.Telemetry.makeCard()
    var gimbalTokenCard: TokenCard = DroneCardKit.Token.Gimbal.makeCard()
    
    var gimbal: ExecutableTokenCard?
    var drone: ExecutableTokenCard?
    let expectationTimeout: TimeInterval = 1000
    
    override func setUp() {
        super.setUp()
        
        runLoop { self.aircraft != nil }
        
        guard let aircraft = self.aircraft else {
            XCTFail("Drone does not exist")
            return
        }
        
        self.drone = DJIDroneToken(with: droneTelemetryTokenCard, for: aircraft)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
}
