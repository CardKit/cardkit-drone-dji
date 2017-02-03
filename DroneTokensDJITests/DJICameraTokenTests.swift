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
    
    
    let cameraOptions: Set<CameraPhotoOption> = [CameraPhotoOption.aspectRatio(.aspect_16x9), CameraPhotoOption.quality(.normal)]
    
    func testCameraTokenPhoto() {
        print("test camera token photo")
        
        guard let camera = self.cameraExecutableTokenCard else {
            XCTFail("Camera does not exist")
            return
        }
        
        camera.takePhoto(cameraMode: .shootPhoto, shootMode: .single, aspectRatio: .ratio16_9, quality: .excellent) { (error) in
            XCTAssertNil(error, "Took Photo")
        }
    }
    
    func testCameraTokenHDRPhoto() {
        print("test camera token HDR photo")
        
        guard let camera = self.cameraExecutableTokenCard else {
            XCTFail("Camera does not exist")
            return
        }
        
        camera.takeHDRPhoto(options: cameraOptions) { (error) in
            XCTAssertNil(error, "Took HDR Photo")
        }
    }
    
    func testCameraTokenTestPhotoBurst() {
        print("test camera token photo burst")
        
        guard let camera = self.cameraExecutableTokenCard else {
            XCTFail("Camera does not exist")
            return
        }
        
        camera.takePhotoBurst(count: PhotoBurstCount.burst_10, options: cameraOptions) { (error) in
            XCTAssertNil(error, "Took Photo Burst")
        }
    }
    
    func testCameraTokenPhotoSeries() {
        print("test camera token start and stop photos")
        
        guard let camera = self.cameraExecutableTokenCard else {
            XCTFail("Camera does not exist")
            return
        }
    }
}
