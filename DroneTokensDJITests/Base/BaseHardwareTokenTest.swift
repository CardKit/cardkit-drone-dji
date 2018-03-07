/**
 * Copyright 2018 IBM Corp. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import XCTest
import DJISDK
import CardKit
import DroneCardKit

@testable import DroneTokensDJI

class BaseHardwareTokenTest: XCTestCase, DJISDKManagerDelegate {
    let expectationTimeout: TimeInterval = 1000
    
    let appKey = "fd1211a6c15ac26860028367"   // CHANGE APP KEY TO RUN YOUR TEST; MAKE SURE BUNDLE ID MATCHES HostApplicationForTests bundle ID
    let bridgeAppIP: String? = "10.10.10.243" // CHANGE TO MATCH THE DEBUG ID IN THE DJI BRIDGE APP
    
    var product: DJIBaseProduct?
    var aircraft: DJIAircraft?
    var isConnected: Bool = false
    var error: Error?
    
    override func setUp() {
        super.setUp()
        
        // don't continue the test if a failure occurs
        super.continueAfterFailure = false
        
        // register with the DJI SDK
        DJISDKManager.registerApp(with: self)
        
        // asynchronous processes in setUp() must be handled with RunLoop and not XCTestExpections;
        // semaphores blocked the callbacks expected from DJI
        while !self.isConnected && self.error == nil {
            RunLoop.current.run(mode: .defaultRunLoopMode, before: Date.distantFuture)
        }
        
        if let error = self.error {
            XCTFail("\(error)")
        }
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        DJISDKManager.stopConnectionToProduct()
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
    
    // MARK: - DJISDKManagerDelegate
    
    func appRegisteredWithError(_ error: Error?) {
        if let error = error {
            self.error = error
            return
        }
        
        let connectionSuccess = DJISDKManager.startConnectionToProduct()
        if !connectionSuccess {
            self.error = error
            return
        }
        
        // time out after 5 seconds if we didn't connect
        let fiveSeconds = DispatchTime.now() + .seconds(5)
        DispatchQueue.main.asyncAfter(deadline: fiveSeconds, execute: {
            if !self.isConnected {
                DJISDKManager.stopConnectionToProduct()
                self.error = DJIHardwareTokenTestError.productConnectionTimedOut
            }
        })
        
        if let bridgeAppIP = self.bridgeAppIP {
            DJISDKManager.enableBridgeMode(withBridgeAppIP: bridgeAppIP)
        }
    }
    
    func productConnected(_ product: DJIBaseProduct?) {
        guard let product = product else {
            print("productConnected called, but product is nil")
            self.product = nil
            self.error = DJIHardwareTokenTestError.failedToObtainProduct
            return
        }
        
        self.product = product
        self.aircraft = self.product as? DJIAircraft
        
        if let model = product.model {
            print("connected to DJI product: \(model)")
        }
        
        self.isConnected = true
    }
    
    func productDisconnected() {
        self.product = nil
        self.aircraft = nil
        self.isConnected = false
    }
}

enum DJIHardwareTokenTestError: Error {
    case productConnectionTimedOut
    case failedToObtainProduct
}
