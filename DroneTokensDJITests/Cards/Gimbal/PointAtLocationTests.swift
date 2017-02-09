//
//  PointAtLocationTests.swift
//  DroneTokensDJI
//
//  Created by ismails on 2/9/17.
//  Copyright © 2017 IBM. All rights reserved.
//

@testable import DroneTokensDJI

import XCTest

import DroneCardKit
import DJISDK

class PointAtLocationTests: DJIHardwareTokenTest {
    
    var gimbal: GimbalToken?
    var drone: DroneToken?
    
    override func setUp() {
        super.setUp()
        
        runLoop { self.aircraft?.gimbal != nil }
        
        guard let aircraft = self.aircraft else {
            XCTFail("Drone does not exist")
            return
        }
        
        self.drone = DJIDroneToken(with: DroneCardKit.Token.Drone.makeCard(), for: aircraft)
        
        guard let gimbalHardware = aircraft.gimbal else {
            XCTFail("Gimbal does not exist")
            return
        }
        
        self.gimbal = DJIGimbalToken(with: DroneCardKit.Token.Gimbal.makeCard(), for: gimbalHardware)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testPointAtLocationCard() {
        // land card
        let pointAtLocation = PointAtLocation(with: DroneCardKit.Action.Tech.Gimbal.PointAtLocation.makeCard())
        
        guard let droneTokenSlot = land.actionCard.tokenSlots.slot(named: "Drone") else {
            XCTFail("expected Land card to have slot named Drone")
            return
        }
        
        // drone token card
        let droneCard = DroneCardKit.Token.Drone.makeCard()
        
        // drone token instance
        let dummyDrone = DummyDroneToken(with: droneCard)
        
        // bind
        land.setup([:], tokens: [droneTokenSlot: dummyDrone])
        
        // execute
        land.main()
        
        XCTAssertTrue(dummyDrone.calledFunctions.contains("land"), "land should have been called")
        XCTAssertTrue(dummyDrone.calledFunctions.count == 1, "only one card should have been called")
    }
    
}
