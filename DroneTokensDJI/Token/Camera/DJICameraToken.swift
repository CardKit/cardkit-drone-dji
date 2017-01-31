//
//  DJICameraToken.swift
//  DroneTokensDJI
//
//  Created by Justin Weisz on 1/24/17.
//  Copyright © 2017 IBM. All rights reserved.
//

import Foundation

import CardKit
import CardKitRuntime
import DroneCardKit

import DJISDK

// MARK: DJICameraToken

public class DJICameraToken: ExecutableTokenCard {
    private let camera: DJICamera
    private let cameraDelegate: CameraDelegate = CameraDelegate()
    
    public init(with card: TokenCard, for camera: DJICamera) {
        self.camera = camera
        camera.delegate = self.cameraDelegate
        super.init(with: card)
    }
    
    func takePhoto(cameraMode: DJICameraMode, shootMode: DJICameraShootPhotoMode, aspectRatio: DJICameraPhotoAspectRatio?, quality: DJICameraPhotoQuality?, completionHandler: CameraTokenCompletionHandler?) {
        self.takePhoto(cameraMode: cameraMode, shootMode: shootMode, interval: nil, aspectRatio: aspectRatio, quality: quality, completionHandler: completionHandler)
    }
    
    //swiftlint:disable:next function_parameter_count
    //swiftlint:disable:next function_body_length
    func takePhoto(cameraMode: DJICameraMode, shootMode: DJICameraShootPhotoMode, interval: DJICameraPhotoIntervalParam?, aspectRatio: DJICameraPhotoAspectRatio?, quality: DJICameraPhotoQuality?, completionHandler: CameraTokenCompletionHandler?) {
        self.camera.setCameraMode(cameraMode, withCompletion: {
            error in
            
            if error != nil {
                completionHandler?(DJICameraTokenError.failedToSetCameraModeToPhoto)
                return
            }
            
            // make sure there is enough space on the SD card
            guard let sdState = self.cameraDelegate.sdCardState else {
                completionHandler?(DJICameraTokenError.failedToObtainSDCardState)
                return
            }
            
            if sdState.availableCaptureCount <= 0 {
                completionHandler?(DJICameraTokenError.sdCardFull)
                return
            }
            
            // set the aspect ratio
            if let aspectRatio = aspectRatio {
                let semaphore = DispatchSemaphore(value: 0)
                var djiError: Error? = nil
                
                self.camera.setPhotoRatio(aspectRatio, withCompletion: {
                    error in
                    djiError = error
                    semaphore.signal()
                })
                
                // wait for the photo ratio to be set
                semaphore.wait()
                
                // check if there was an error
                if djiError != nil {
                    completionHandler?(djiError)
                    return
                }
            }
            
            // set the quality
            if let quality = quality {
                let semaphore = DispatchSemaphore(value: 0)
                var djiError: Error? = nil
                
                self.camera.setPhotoQuality(quality, withCompletion: {
                    error in
                    djiError = error
                    semaphore.signal()
                })
                
                // wait for the photo ratio to be set
                semaphore.wait()
                
                // check if there was an error
                if djiError != nil {
                    completionHandler?(djiError)
                    return
                }
            }
            
            // set the interval (if we're taking photos in an interval)
            if shootMode == .interval, let interval = interval {
                let semaphore = DispatchSemaphore(value: 0)
                var djiError: Error? = nil
                
                self.camera.setPhotoIntervalParam(interval, withCompletion: {
                    error in
                    djiError = error
                    semaphore.signal()
                })
                
                // wait for the interval to be set
                semaphore.wait()
                
                // check if there was an error
                if djiError != nil {
                    completionHandler?(djiError)
                    return
                }
            }
            
            // take the photo
            self.camera.startShootPhoto(shootMode, withCompletion: {
                error in
                completionHandler?(error)
            })
        })
    }
    
    func stopPhotos(completionHandler: CameraTokenCompletionHandler?) {
        self.camera.stopShootPhoto(completion: {
            error in
            completionHandler?(error)
        })
    }
}

extension DJICameraToken {
    fileprivate class func aspectRatio(from options: Set<CameraPhotoOption>) -> DJICameraPhotoAspectRatio? {
        for option in options {
            if case .aspectRatio(let r) = option {
                return r.djiAspectRatio
            }
        }
        return nil
    }
    
    fileprivate class func quality(from options: Set<CameraPhotoOption>) -> DJICameraPhotoQuality? {
        for option in options {
            if case .quality(let q) = option {
                return q.djiQuality
            }
        }
        return nil
    }
}

// MARK: CameraToken

extension DJICameraToken: CameraToken {
    public func takePhoto(options: Set<CameraPhotoOption>, completionHandler: CameraTokenCompletionHandler?) {
        let cameraMode: DJICameraMode = .shootPhoto
        let shootMode: DJICameraShootPhotoMode = .single
        let aspectRatio: DJICameraPhotoAspectRatio? = DJICameraToken.aspectRatio(from: options)
        let quality: DJICameraPhotoQuality? = DJICameraToken.quality(from: options)
        
        // take the photo
        self.takePhoto(cameraMode: cameraMode, shootMode: shootMode, aspectRatio: aspectRatio, quality: quality, completionHandler: completionHandler)
    }
    
    public func takeHDRPhoto(options: Set<CameraPhotoOption>, completionHandler: CameraTokenCompletionHandler?) {
        let cameraMode: DJICameraMode = .shootPhoto
        let shootMode: DJICameraShootPhotoMode = .HDR
        let aspectRatio: DJICameraPhotoAspectRatio? = DJICameraToken.aspectRatio(from: options)
        let quality: DJICameraPhotoQuality? = DJICameraToken.quality(from: options)
        
        // take the photo
        self.takePhoto(cameraMode: cameraMode, shootMode: shootMode, aspectRatio: aspectRatio, quality: quality, completionHandler: completionHandler)
    }
    
    public func takePhotoBurst(count: PhotoBurstCount, options: Set<CameraPhotoOption>, completionHandler: CameraTokenCompletionHandler?) {
        let cameraMode: DJICameraMode = .shootPhoto
        let shootMode: DJICameraShootPhotoMode = .burst
        let aspectRatio: DJICameraPhotoAspectRatio? = DJICameraToken.aspectRatio(from: options)
        let quality: DJICameraPhotoQuality? = DJICameraToken.quality(from: options)
        
        // take the photo
        self.takePhoto(cameraMode: cameraMode, shootMode: shootMode, aspectRatio: aspectRatio, quality: quality, completionHandler: completionHandler)
    }
    
    public func startTakingPhotos(at interval: TimeInterval, options: Set<CameraPhotoOption>, completionHandler: CameraTokenCompletionHandler?) {
        let cameraMode: DJICameraMode = .shootPhoto
        let shootMode: DJICameraShootPhotoMode = .interval
        let aspectRatio: DJICameraPhotoAspectRatio? = DJICameraToken.aspectRatio(from: options)
        let quality: DJICameraPhotoQuality? = DJICameraToken.quality(from: options)
        
        // figure out the interval
        // a captureCount of 255 means the camera will continue taking photos until stopShootPhotoWithCompletion() is called
        let djiInterval = DJICameraPhotoIntervalParam(captureCount: 255, timeIntervalInSeconds: UInt16(interval))
        
        // take the photos
        self.takePhoto(cameraMode: cameraMode, shootMode: shootMode, interval: djiInterval, aspectRatio: aspectRatio, quality: quality, completionHandler: completionHandler)
    }
    
    public func stopTakingPhotos(completionHandler: CameraTokenCompletionHandler?) {
        self.stopPhotos(completionHandler: completionHandler)
    }
    
    public func startTimelapse(options: Set<CameraPhotoOption>, completionHandler: CameraTokenCompletionHandler?) {
        let cameraMode: DJICameraMode = .shootPhoto
        let shootMode: DJICameraShootPhotoMode = .timeLapse
        let aspectRatio: DJICameraPhotoAspectRatio? = DJICameraToken.aspectRatio(from: options)
        let quality: DJICameraPhotoQuality? = DJICameraToken.quality(from: options)
        
        // take the photos
        self.takePhoto(cameraMode: cameraMode, shootMode: shootMode, aspectRatio: aspectRatio, quality: quality, completionHandler: completionHandler)
    }
    
    public func stopTimelapse(completionHandler: CameraTokenCompletionHandler?) {
        self.stopPhotos(completionHandler: completionHandler)
    }
    
    public func startVideo(options: Set<CameraVideoOption>, completionHandler: CameraTokenCompletionHandler?) {
        
    }
    
    public func stopVideo(completionHandler: CameraTokenCompletionHandler?) {
        
    }
}

// MARK: - PhotoAspectRatio Extensions

extension PhotoAspectRatio {
    var djiAspectRatio: DJICameraPhotoAspectRatio {
        switch self {
        case .aspect_16x9:
            return .ratio16_9
        case .aspect_3x2:
            return .ratio3_2
        case .aspect_4x3:
            return .ratio4_3
        }
    }
}

// MARK: - PhotoQuality Extensions

extension PhotoQuality {
    var djiQuality: DJICameraPhotoQuality {
        switch self {
        case .excellent:
            return .excellent
        case .fine:
            return .fine
        case .normal:
            return .normal
        }
    }
}

// MARK: - DJICameraTokenError

public enum DJICameraTokenError: Error {
    case failedToSetCameraModeToPhoto
    case failedToObtainSDCardState
    case sdCardFull
    case failedToSetCameraPhotoAspectRatio
    case failedToSetCameraPhotoQuality
}

// MARK: - CameraDelegate

// DJICameraDelegates must inherit from NSObject. We can't make DJICameraToken inherit from
// NSObject since it inherits from ExecutableTokenCard (which isn't an NSObject), so we use a private
// class for this instead.
fileprivate class CameraDelegate: NSObject, DJICameraDelegate {
    var lensState: DJICameraLensState?
    var sdCardState: DJICameraSDCardState?
    var ssdState: DJICameraSSDState?
    var systemState: DJICameraSystemState?
    
    func camera(_ camera: DJICamera, didUpdate ssdState: DJICameraSSDState) {
        self.ssdState = ssdState
    }
    
    func camera(_ camera: DJICamera, didUpdate lensState: DJICameraLensState) {
        self.lensState = lensState
    }
    
    func camera(_ camera: DJICamera, didGenerateNewMediaFile newMedia: DJIMedia) {
        // tbd
    }
    
    func camera(_ camera: DJICamera, didUpdate sdCardState: DJICameraSDCardState) {
        self.sdCardState = sdCardState
    }
    
    func camera(_ camera: DJICamera, didUpdate systemState: DJICameraSystemState) {
        self.systemState = systemState
    }
    
    func camera(_ camera: DJICamera, didUpdateTemperatureData temperature: Float) {
        // tbd
    }
    
    func camera(_ camera: DJICamera, didGenerateTimeLapsePreview previewImage: UIImage) {
        // tbd
    }
    
    func camera(_ camera: DJICamera, didUpdate externalSceneSettings: DJICameraThermalExternalSceneSettings) {
        // tbd
    }
    
    func camera(_ camera: DJICamera, didUpdateCurrentExposureParameters params: DJICameraExposureParameters) {
        // tbd
    }
    
    func camera(_ camera: DJICamera, didReceiveVideoData videoBuffer: UnsafeMutablePointer<UInt8>, length size: Int) {
        // tbd
    }
    
    func camera(_ camera: DJICamera, didUpdate temperatureAggregations: DJICameraThermalAreaTemperatureAggregations) {
        // tbd
    }
}
