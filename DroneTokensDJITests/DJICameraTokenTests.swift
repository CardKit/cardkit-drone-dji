//
//  DJICameraTokenTests.swift
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


class DJICameraTokenTests: DJIHardwareTokenTest {
    
    //These tests are best run individually so the resulting photo, video or lack thereof can be verified.
    
    //Sometimes camera is nil.  Keep trying until it isn't.
    
    let expectationTimeout: TimeInterval = 1000
    var cameraTokenCard: TokenCard?
    var cameraExecutableTokenCard: DJICameraToken?
    let cameraOptions: Set<CameraPhotoOption> = [CameraPhotoOption.aspectRatio(.aspect_16x9), CameraPhotoOption.quality(.normal)]
    
    override func setUp() {
        super.setUp()
        print("setup of DJICameraTokenTests")
        
        //setup camera
        guard let camera = self.aircraft?.camera else {
            XCTFail("No camera exists")
            return
        }
        
        self.cameraTokenCard = DroneCardKit.Token.Camera.makeCard()
        self.cameraExecutableTokenCard = DJICameraToken(with: self.cameraTokenCard!, for: camera)
        
        XCTAssertNotNil(self.cameraTokenCard, "Camera Token Card could not be created.")
        XCTAssertNotNil(self.cameraExecutableTokenCard, "Camera Executable Token Card could not be created.")
        
    }
    
    func testCameraTokenPhoto() {
        print("test camera token photo")
        
        let cameraExpectation = expectation(description: "take photo expectation")
        cameraExecutableTokenCard?.takePhoto(options: cameraOptions) { (error) in
            print("error taking photo \(error)")
            XCTAssertNil(error, "Took Photo")
            cameraExpectation.fulfill()
        }
        
        waitForExpectations(timeout: expectationTimeout) { (error) in
            if let error = error {
                XCTFail("Take photo timed out.  Error: \(error)")
            }
        }

    }
    
    func testCameraTokenHDRPhoto() {
        print("test camera token HDR photo")
        
        let cameraExpectation = expectation(description: "take HDR photo expectation")
        cameraExecutableTokenCard?.takeHDRPhoto(options: cameraOptions) { (error) in
            XCTAssertNil(error, "Took HDR Photo")
            cameraExpectation.fulfill()
        }
        
        waitForExpectations(timeout: expectationTimeout) { (error) in
            if let error = error {
                XCTFail("Take HDR photo timed out.  Error: \(error)")
            }
        }
    }
    
    func testCameraTokenTestPhotoBurst() {
        print("test camera token photo burst")
        
        let cameraExpectation = expectation(description: "take photo burst expectation")
        cameraExecutableTokenCard?.takePhotoBurst(count: PhotoBurstCount.burst_7, options: cameraOptions) { (error) in
            XCTAssertNil(error, "Took Photo Burst")
            cameraExpectation.fulfill()
        }
        
        waitForExpectations(timeout: expectationTimeout) { (error) in
            if let error = error {
                XCTFail("Take photo burst timed out.  Error: \(error)")
            }
        }
    }
    
    func testCameraTokenPhotoSeries() {
        
    }
    
    func testCameraTokenTimelapse() {
        
    }
    
    func testCameraTokenVideo() {
        
    }
}
