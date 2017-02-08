//
//  DJIHardwareTokenTest.swift
//  DroneTokensDJI
//
//  Created by Kristina M Brimijoin on 2/1/17.
//  Copyright © 2017 IBM. All rights reserved.
//

import XCTest
import DJISDK
import CardKit
import DroneCardKit
@testable import DroneTokensDJI

class DJIHardwareTokenTest: XCTestCase, DJISDKManagerDelegate {
    
    let appKey = "fd1211a6c15ac26860028367"  //CHANGE APP KEY TO RUN YOUR TEST; MAKE SURE BUNDLE ID MATCHES HostApplicationForTests bundle ID
    let enterDebugMode = true
    var registered = false
//    let semaphoreTimeout = DispatchTime.now() + DispatchTimeInterval.seconds(120)
//    var semaphore = DispatchSemaphore(value: 0)
    var connectedDJIProduct: DJIBaseProduct?
    var aircraft: DJIAircraft?
    
    //camera
    var cameraTokenCard: TokenCard?
    var cameraExecutableTokenCard: DJICameraToken?
    
    
    override func setUp() {
        super.setUp()
        
        registered = false
        
        DJISDKManager.registerApp(appKey, with: self)
        
        runLoop { registered }
        
        //asynchronous processes in setUp() must be handled with semaphores and not XCTestExpections
        /*let result = semaphore.wait(timeout: semaphoreTimeout)
        
        if result == .timedOut {
            XCTFail("Application and DJI Product Registration timed out")
        }*/
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        //let cameraToken = DJICameraToken
        print("test example")
    }
    
    // MARK: - DJISDKManagerDelegate
    
    func sdkManagerProductDidChange(from oldProduct: DJIBaseProduct?, to newProduct: DJIBaseProduct?) {
        guard let newProduct = newProduct else {
            print("Status: No Product Connected (Product Disconnected)")
            connectedDJIProduct = nil
            return
        }
        
        // set connected dji product
        connectedDJIProduct = newProduct
        self.aircraft = connectedDJIProduct as? DJIAircraft
        
        //Updates the product's model
        print("Model: \((newProduct.model)!)")
        print("Product changed from: \(oldProduct?.model) to \((newProduct.model)!)")
        
        //moving code to access specific hardware inside the tests that deal with that hardware (e.g. DJIGimbalTokenTests).
        //left camera here for now as Krissy is still working on it.
        if let camera = aircraft?.camera {
            self.cameraTokenCard = DroneCardKit.Token.Camera.makeCard()
            self.cameraExecutableTokenCard = DJICameraToken(with: self.cameraTokenCard!, for: camera)
        }
        
//        old code to setup camera
//        guard let camera = self.aircraft?.camera else {
//            XCTFail("No camera exists")
//            return
//        }
//        
//        self.cameraTokenCard = DroneCardKit.Token.Camera.makeCard()
//        self.cameraExecutableTokenCard = DJICameraToken(with: self.cameraTokenCard!, for: camera)
     
        //semaphore.signal()
        
        registered = true
        
    }
    
    func sdkManagerDidRegisterAppWithError(_ error: Error?) {
        if let error = error {
            print("whole error \(error)")
            print("Application Registration Error: \(error.localizedDescription)")
            //semaphore.signal()
            //registrationExpectation?.fulfill()
            XCTFail("\(error.localizedDescription)")
        } else {
            print("DJISDK Registered Successfully")
            
            
            if enterDebugMode {
                print("enterDebugMode")
                DJISDKManager.enterDebugMode(withDebugId: "192.168.1.4")
                /*let result = semaphore.wait(timeout: semaphoreTimeout)
                
                if result == .timedOut {
                    XCTFail("Application and DJI Product Registration timed out")
                }*/
            } else {
                let connStatus = DJISDKManager.startConnectionToProduct()
                if connStatus {
                    print("Looking for DJI Products...")
                }
            }
        }
    }
    
    func runLoop(until: () -> Bool) {
        while !until() {
            let calendar = Calendar.current
            var limitDate = Date.distantFuture
            
            if let date = calendar.date(byAdding: .second, value: 5, to: Date()) {
                limitDate = date
            }
            
            RunLoop.current.run(mode: .defaultRunLoopMode, before: limitDate)
        }
    }
}
