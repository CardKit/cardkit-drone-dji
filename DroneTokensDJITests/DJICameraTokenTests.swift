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
    var cameraExecutableTokenCard: DJICameraToken?
    let cameraOptions: Set<CameraPhotoOption> = [CameraPhotoOption.aspectRatio(.aspect_16x9), CameraPhotoOption.quality(.normal)]
    let videoOptions: Set<CameraVideoOption> = [CameraVideoOption.framerate(.framerate_50fps), CameraVideoOption.resolution(.resolution_720p)]
    
    
    override func setUp() {
        super.setUp()
        print("setup of DJICameraTokenTests")
    
        runLoop { self.aircraft?.camera != nil }
        
        print("camera found: \(self.aircraft?.camera)")
        
        //setup camera
        guard let camera = self.aircraft?.camera else {
            //because these tests are hardware tests and are part of continuous integration on build server, they should not fail if there is no hardware.  Instead, we asser that there is not hardware.
            XCTAssertNil(self.aircraft?.camera, "NO CAMERA HARDWARE")
            return
        }
        
        print("Camera Video Resolution and Frame Rate Range: \(DJICameraParameters.sharedInstance().supportedCameraVideoResolutionAndFrameRateRange())")        
        
        let cameraTokenCard = DroneCardKit.Token.Camera.makeCard()
        self.cameraExecutableTokenCard = DJICameraToken(with: cameraTokenCard, for: camera)
        
        XCTAssertNotNil(self.cameraExecutableTokenCard, "Camera Executable Token Card could not be created.")
        
    }
    
    func testCameraTokenPhoto() {
        print("test camera token photo")
        
        let cameraExpectation = expectation(description: "take photo expectation")
        
        DispatchQueue.global(qos: .default).async {
            do {
                try self.cameraExecutableTokenCard?.takePhoto(options: self.cameraOptions)
            } catch {
                print("error taking photo \(error)")
                XCTAssertNil(error, "Took Photo")
            }
            
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
        
        DispatchQueue.global(qos: .default).async {
            do {
                try self.cameraExecutableTokenCard?.takeHDRPhoto(options: self.cameraOptions)
            } catch {
                print("error taking HDR Photo \(error)")
                XCTAssertNil(error, "Took HDR Photo")
            }
            
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
        
        DispatchQueue.global(qos: .default).async {
            do {
                try self.cameraExecutableTokenCard?.takePhotoBurst(count: PhotoBurstCount.burst_3, options: self.cameraOptions)
            } catch {
                XCTAssertNil(error, "Took Photo Burst")
            }
            
            cameraExpectation.fulfill()
        }
        
        waitForExpectations(timeout: expectationTimeout) { (error) in
            if let error = error {
                XCTFail("Take photo burst timed out.  Error: \(error)")
            }
        }
    }
    
   
    func testCameraTokenPhotoSeries() {
        let cameraExpectation = expectation(description: "take photo series")
        let backgroundQueue = DispatchQueue(label: "photo.series")
        let timeInterval: TimeInterval = 5.0
        let duration = DispatchTime.now() + .seconds(20)
        
        backgroundQueue.async {
            do {
                print("start taking interval photos")
                try self.cameraExecutableTokenCard?.startTakingPhotos(at: timeInterval, options: self.cameraOptions)
                
                backgroundQueue.asyncAfter(deadline: duration, execute: { 
                    do {
                        print("stop taking photos")
                        try self.cameraExecutableTokenCard?.stopTakingPhotos()
                        cameraExpectation.fulfill()
                    } catch {
                        XCTAssertNil(error, "Took Photo Series - stopped taking photos")
                        cameraExpectation.fulfill()
                    }
                })
            } catch {
                XCTAssertNil(error, "Took Photo Series - started taking photos")
            }
        }
        
        waitForExpectations(timeout: expectationTimeout) { (error) in
            if let error = error {
                XCTFail("Photo series timed out.  Error: \(error)")
            }
        }
    }
    
    //NOT SUPPORTED BY MAVIC PRO
    func testCameraTokenTimelapse() {
        let cameraExpectation = expectation(description: "take timelapse")
        DispatchQueue.global(qos: .default).async {
            do {
                try self.cameraExecutableTokenCard?.startTimelapse(options: self.cameraOptions)
                cameraExpectation.fulfill()
            } catch {
                XCTAssertNil(error, "Timelapse - started")
            }
        }
        waitForExpectations(timeout: expectationTimeout) { (error) in
            if let error = error {
                XCTFail("Photo timelapse timed out.  Error: \(error)")
            }
        }
    }
    
    func testCameraTokenVideo() {
        let cameraExpectation = expectation(description: "record video")
        let duration = DispatchTime.now() + .seconds(10)
        let backgroundQueue = DispatchQueue(label: "record-video")
        
        //start taking photos at interval
        backgroundQueue.async {
            do {
                print("start recording")
                try self.cameraExecutableTokenCard?.startVideo(options: self.videoOptions)
                
                backgroundQueue.asyncAfter(deadline: duration, execute: { 
                    do {
                        print("stop recording")
                        try self.cameraExecutableTokenCard?.stopVideo()
                        cameraExpectation.fulfill()
                    } catch {
                        XCTAssertNil(error, "Took Video - stopped taking video")
                        cameraExpectation.fulfill()
                    }
                })
            } catch {
                XCTFail("Take video failed. \(error)")
            }            
        }

        waitForExpectations(timeout: expectationTimeout) { (error) in
            if let error = error {
                XCTFail("Record video timed out.  Error: \(error)")
            }
        }

    }
}
