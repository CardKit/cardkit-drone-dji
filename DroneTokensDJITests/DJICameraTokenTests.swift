//
//  DJICameraTokenTests.swift
//  DroneTokensDJI
//
//  Created by Kristina M Brimijoin on 2/1/17.
//  Copyright © 2017 IBM. All rights reserved.
//

import XCTest
@testable import DroneTokensDJI
import DroneCardKit
import DJISDK

class DJICameraTokenTests: DJIHardwareTokenTest {
    
    //These tests are best run individually so the resulting photo, video or lack thereof can be verified.
    
    //Sometimes camera is nil.  Keep trying until it isn't.
    
    let expectationTimeout: TimeInterval = 1000
    let cameraOptions: Set<CameraPhotoOption> = [CameraPhotoOption.aspectRatio(.aspect_16x9), CameraPhotoOption.quality(.normal)]
    
    func testCameraTokenPhoto() {
        print("test camera token photo")
        
        guard let camera = self.cameraExecutableTokenCard else {
            XCTFail("Camera does not exist")
            return
        }
        
        let cameraExpectation = expectation(description: "take photo expectation")
        camera.takePhoto(options: cameraOptions) { (error) in
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
        
        guard let camera = self.cameraExecutableTokenCard else {
            XCTFail("Camera does not exist")
            return
        }
        
        let cameraExpectation = expectation(description: "take HDR photo expectation")
        camera.takeHDRPhoto(options: cameraOptions) { (error) in
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
        
        guard let camera = self.cameraExecutableTokenCard else {
            XCTFail("Camera does not exist")
            return
        }
        
        let cameraExpectation = expectation(description: "take photo burst expectation")
        camera.takePhotoBurst(count: PhotoBurstCount.burst_10, options: cameraOptions) { (error) in
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
