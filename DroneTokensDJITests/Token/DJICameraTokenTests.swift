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

@testable import CardKit
@testable import DroneCardKit
@testable import DroneTokensDJI

import DJISDK

// These tests are best run individually so the resulting photo, video, or lack thereof can be verified.
class DJICameraTokenTests: BaseHardwareTokenTest {
    var camera: DJICameraToken?
    let cameraOptions: Set<CameraPhotoOption> = [CameraPhotoOption.aspectRatio(.aspect16x9)]
    let videoOptions: Set<CameraVideoOption> = [CameraVideoOption.framerate(.framerate50fps), CameraVideoOption.resolution(.resolution720p)]
    let cameraDuration: Int = 3
    
    override func setUp() {
        super.setUp()
        
        // Sometimes camera is nil.  Keep trying until it isn't.
        runLoop { self.aircraft?.camera != nil }
        
        print("camera found: \(String(describing: self.aircraft?.camera))")
        
        // setup camera
        guard let cameraHardware = self.aircraft?.camera else {
            // because these tests are hardware tests and are part of continuous integration on build server, they should not fail if there is no hardware.  Instead, we assert that there is not hardware.
            XCTAssertNil(self.aircraft?.camera, "NO CAMERA HARDWARE")
            return
        }
        
        //let cameraCapabilities = DJICameraCapabilities()
        //print("camera video resolution and framerate range: \(cameraCapabilities.videoResolutionAndFrameRateRange())")
        
        self.camera = DJICameraToken(with: DroneCardKit.Token.Camera.makeCard(), for: cameraHardware)
        XCTAssertNotNil(self.camera, "camera token card could not be created")
    }
    
    func testTakePhoto() {
        let cameraExpectation = expectation(description: "take photo expectation")
        
        DispatchQueue.global(qos: .default).async {
            do {
                _ = try self.camera?.takePhoto(options: self.cameraOptions)
            } catch {
                print("error taking photo \(error)")
                XCTAssertNil(error, "error should be nil")
            }
            
            cameraExpectation.fulfill()
        }
        
        waitForExpectations(timeout: expectationTimeout) { (error) in
            if let error = error {
                XCTFail("Take photo timed out.  Error: \(error)")
            }
        }
    }
    
    func testTakeHDRPhoto() {
        let cameraExpectation = expectation(description: "take HDR photo expectation")
        
        DispatchQueue.global(qos: .default).async {
            do {
                _ = try self.camera?.takeHDRPhoto(options: self.cameraOptions)
            } catch {
                print("error taking HDR Photo \(error)")
                XCTAssertNil(error, "error should be nil")
            }
            
            cameraExpectation.fulfill()
        }
        
        waitForExpectations(timeout: expectationTimeout) { (error) in
            if let error = error {
                XCTFail("Take HDR photo timed out.  Error: \(error)")
            }
        }
    }
    
    func testTakePhotoBurst() {
        print("test camera token photo burst")
        
        let cameraExpectation = expectation(description: "take photo burst expectation")
        
        DispatchQueue.global(qos: .default).async {
            do {
                _ = try self.camera?.takePhotoBurst(count: DCKPhotoBurstCount.burst3, options: self.cameraOptions)
            } catch {
                XCTAssertNil(error, "error should be nil")
            }
            
            cameraExpectation.fulfill()
        }
        
        waitForExpectations(timeout: expectationTimeout) { (error) in
            if let error = error {
                XCTFail("Take photo burst timed out.  Error: \(error)")
            }
        }
    }
    
    func testTakePhotos() {
        let cameraExpectation = expectation(description: "take photo series")
        let backgroundQueue = DispatchQueue(label: "photos")
        let timeInterval: TimeInterval = 5.0
        let duration = DispatchTime.now() + .seconds(self.cameraDuration)
        
        backgroundQueue.async {
            do {
                try self.camera?.startTakingPhotos(at: timeInterval, options: self.cameraOptions)
                
                backgroundQueue.asyncAfter(deadline: duration, execute: { 
                    do {
                        _ = try self.camera?.stopTakingPhotos()
                    } catch {
                        XCTAssertNil(error, "error should be nil")
                    }
                    
                    cameraExpectation.fulfill()
                })
            } catch {
                XCTAssertNil(error, "error should be nil")
            }
        }
        
        waitForExpectations(timeout: expectationTimeout) { (error) in
            if let error = error {
                XCTFail("Photo series timed out.  Error: \(error)")
            }
        }
    }
    
    func testTakeTimelapse() {
        let cameraExpectation = expectation(description: "take timelapse")
        let backgroundQueue = DispatchQueue(label: "timelapse")
        let duration = DispatchTime.now() + .seconds(self.cameraDuration)
        
        backgroundQueue.async {
            do {
                try self.camera?.startTimelapse(options: self.cameraOptions)
                
                backgroundQueue.asyncAfter(deadline: duration, execute: {
                    do {
                        _ = try self.camera?.stopTimelapse()
                    } catch {
                        XCTAssertNil(error, "error should be nil")
                    }
                    
                    cameraExpectation.fulfill()
                })
                
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
    
    func testCameraRecordVideo() {
        let cameraExpectation = expectation(description: "record video")
        let backgroundQueue = DispatchQueue(label: "recordVideo")
        let duration = DispatchTime.now() + .seconds(self.cameraDuration)
        
        backgroundQueue.async {
            do {
                try self.camera?.startVideo(options: self.videoOptions)
                
                backgroundQueue.asyncAfter(deadline: duration, execute: {
                    do {
                        _ = try self.camera?.stopVideo()
                    } catch {
                        XCTAssertNil(error, "error should be nil")
                    }
                    
                    cameraExpectation.fulfill()
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
