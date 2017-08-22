//
//  BaseDroneTokenTests
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
