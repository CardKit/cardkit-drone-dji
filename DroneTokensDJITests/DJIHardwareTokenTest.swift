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
    let debugId = "192.168.1.9"
    let enterDebugMode = true
    var registered = false
    var connectedDJIProduct: DJIBaseProduct?
    var aircraft: DJIAircraft?
    
    //camera
    var cameraTokenCard: TokenCard?
    var cameraExecutableTokenCard: DJICameraToken?
    
    
    override func setUp() {
        super.setUp()
        
        registered = false

        DJISDKManager.registerApp(appKey, with: self)
        
        //asynchronous processes in setUp() must be handled with RunLoop and not XCTestExpections;
        // semaphores blocked the callbacks expected from DJI
        while !registered {
            RunLoop.current.run(mode: .defaultRunLoopMode, before: Date.distantFuture)
        }
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        DJISDKManager.stopConnectionToProduct()
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
        print("Camera: \(self.aircraft?.camera)")
        
        //setup camera
        guard let camera = self.aircraft?.camera else {
            XCTFail("No camera exists")
            return
        }
        
        self.cameraTokenCard = DroneCardKit.Token.Camera.makeCard()
        self.cameraExecutableTokenCard = DJICameraToken(with: self.cameraTokenCard!, for: camera)
        
        registered = true
        
    }
    
    func sdkManagerDidRegisterAppWithError(_ error: Error?) {
        if let error = error {
            print("Application Registration Error: \(error.localizedDescription)")
            XCTFail("\(error.localizedDescription)")
        } else {
            print("DJISDK Registered Successfully")
            
            if enterDebugMode {                
                DJISDKManager.enterDebugMode(withDebugId: debugId)
            } else {
                let connStatus = DJISDKManager.startConnectionToProduct()
                if connStatus {
                    print("Looking for DJI Products...")
                }
            }
        }
    }
    
}
