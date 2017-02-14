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
    
    //swiftlint:disable:next weak_delegate
    private let cameraDelegate: CameraDelegate = CameraDelegate()
    
    public init(with card: TokenCard, for camera: DJICamera) {
        self.camera = camera
        camera.delegate = self.cameraDelegate
        super.init(with: card)
    }
    
    func takePhoto(cameraMode: DJICameraMode, shootMode: DJICameraShootPhotoMode, aspectRatio: DJICameraPhotoAspectRatio?, quality: DJICameraPhotoQuality?) throws {
        try self.takePhoto(cameraMode: cameraMode, shootMode: shootMode, interval: nil, burstCount: nil, aspectRatio: aspectRatio, quality: quality)
    }
    
    //swiftlint:disable:next function_parameter_count function_body_length
    func takePhoto(cameraMode: DJICameraMode, shootMode: DJICameraShootPhotoMode, interval: DJICameraPhotoIntervalParam?, burstCount: DJICameraPhotoBurstCount?, aspectRatio: DJICameraPhotoAspectRatio?, quality: DJICameraPhotoQuality?) throws {
        
        do {
            try DispatchQueue.executeSynchronously { self.camera.setCameraMode(cameraMode, withCompletion: $0) }
        } catch {
            throw DJICameraTokenError.failedToSetCameraModeToPhoto
        }
        
        // make sure there is enough space on the SD card
        guard let sdState = self.cameraDelegate.sdCardState else {
            throw DJICameraTokenError.failedToObtainSDCardState
        }
        
        if sdState.availableCaptureCount <= 0 {
            throw DJICameraTokenError.sdCardFull
        }
        
        // set the aspect ratio
        if let aspectRatio = aspectRatio {
            try DispatchQueue.executeSynchronously { self.camera.setPhotoRatio(aspectRatio, withCompletion: $0) }
        }
        
        // set the quality
        if let quality = quality {
            try DispatchQueue.executeSynchronously { self.camera.setPhotoQuality(quality, withCompletion: $0) }
        }
        
        // set the burstCount (if we're taking photos in burst mode)
        if shootMode == .burst, let burstCount = burstCount {
            do {
                try DispatchQueue.executeSynchronously { self.camera.setPhotoBurstCount(burstCount, withCompletion: $0) }
            } catch {
                let nsError = error as NSError
                if nsError.code == DJISDKError.invalidParameters.rawValue {
                    //DJISDKError of .invalidParameters typically means that the burst count is not supported by the camera hardware in use.
                    let burstCountErrorDescription = "\(nsError.localizedDescription).  Check to see that the camera supports the burst count provided."
                    let burstCountError = NSError(domain: nsError.domain, code: nsError.code, userInfo: [NSLocalizedDescriptionKey: burstCountErrorDescription])
                    throw burstCountError
                }
            }
        }
        
        // set the interval (if we're taking photos in an interval)
        if shootMode == .interval, let interval = interval {
            try DispatchQueue.executeSynchronously { self.camera.setPhotoIntervalParam(interval, withCompletion: $0) }
        }
        
        // take the photo
        try DispatchQueue.executeSynchronously { self.camera.startShootPhoto(shootMode, withCompletion: $0) }
    }
    
    func stopPhotos() throws {
        try DispatchQueue.executeSynchronously { self.camera.stopShootPhoto(completion: $0) }
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
    public func takePhoto(options: Set<CameraPhotoOption>) throws {
        let cameraMode: DJICameraMode = .shootPhoto
        let shootMode: DJICameraShootPhotoMode = .single
        let aspectRatio: DJICameraPhotoAspectRatio? = DJICameraToken.aspectRatio(from: options)
        let quality: DJICameraPhotoQuality? = DJICameraToken.quality(from: options)
        
        // take the photo
        try self.takePhoto(cameraMode: cameraMode, shootMode: shootMode, aspectRatio: aspectRatio, quality: quality)
    }
    
    public func takeHDRPhoto(options: Set<CameraPhotoOption>) throws {
        let cameraMode: DJICameraMode = .shootPhoto
        let shootMode: DJICameraShootPhotoMode = .HDR
        let aspectRatio: DJICameraPhotoAspectRatio? = DJICameraToken.aspectRatio(from: options)
        let quality: DJICameraPhotoQuality? = DJICameraToken.quality(from: options)
        
        // take the photo
        try self.takePhoto(cameraMode: cameraMode, shootMode: shootMode, aspectRatio: aspectRatio, quality: quality)
    }
    
    public func takePhotoBurst(count: PhotoBurstCount, options: Set<CameraPhotoOption>) throws {
        let cameraMode: DJICameraMode = .shootPhoto
        let shootMode: DJICameraShootPhotoMode = .burst
        let aspectRatio: DJICameraPhotoAspectRatio? = DJICameraToken.aspectRatio(from: options)
        let quality: DJICameraPhotoQuality? = DJICameraToken.quality(from: options)
        
        guard let unsignedCount: UInt = UInt(count.rawValue) else {
            throw DJICameraTokenError.invalidPhotoBurstCountSpecified(count.rawValue)
        }
        
        guard let photoBurstCount: DJICameraPhotoBurstCount = DJICameraPhotoBurstCount(rawValue: unsignedCount) else {
            throw DJICameraTokenError.invalidPhotoBurstCountSpecified(count.rawValue)
        }
        
        // take the photo
        try self.takePhoto(cameraMode: cameraMode, shootMode: shootMode, interval: nil, burstCount: photoBurstCount, aspectRatio: aspectRatio, quality: quality)
    }
    
    public func startTakingPhotos(at interval: TimeInterval, options: Set<CameraPhotoOption>) throws {
        let cameraMode: DJICameraMode = .shootPhoto
        let shootMode: DJICameraShootPhotoMode = .interval
        let aspectRatio: DJICameraPhotoAspectRatio? = DJICameraToken.aspectRatio(from: options)
        let quality: DJICameraPhotoQuality? = DJICameraToken.quality(from: options)
        
        // figure out the interval
        // a captureCount of 255 means the camera will continue taking photos until stopShootPhotoWithCompletion() is called
        let djiInterval = DJICameraPhotoIntervalParam(captureCount: 255, timeIntervalInSeconds: UInt16(interval))
        
        // take the photos
        try self.takePhoto(cameraMode: cameraMode, shootMode: shootMode, interval: djiInterval, burstCount: nil, aspectRatio: aspectRatio, quality: quality)
    }
    
    public func stopTakingPhotos() throws {
        try self.stopPhotos()
    }
    
    public func startTimelapse(options: Set<CameraPhotoOption>) throws {
        let cameraMode: DJICameraMode = .shootPhoto
        let shootMode: DJICameraShootPhotoMode = .timeLapse
        let aspectRatio: DJICameraPhotoAspectRatio? = DJICameraToken.aspectRatio(from: options)
        let quality: DJICameraPhotoQuality? = DJICameraToken.quality(from: options)
        
        // take the photos
        try self.takePhoto(cameraMode: cameraMode, shootMode: shootMode, aspectRatio: aspectRatio, quality: quality)
    }
    
    public func stopTimelapse() throws {
        try self.stopPhotos()
    }
    
    public func startVideo(options: Set<CameraVideoOption>) {
        
    }
    
    public func stopVideo() {
        
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
    case invalidPhotoBurstCountSpecified(Int)
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
