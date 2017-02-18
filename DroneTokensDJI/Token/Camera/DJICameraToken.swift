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
    fileprivate let cameraDelegate: CameraDelegate = CameraDelegate()
    
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

// MARK: CameraToken

extension DJICameraToken: CameraToken {
    public func takePhoto(options: Set<CameraPhotoOption>) throws -> DCKPhoto {
        let cameraMode: DJICameraMode = .shootPhoto
        let shootMode: DJICameraShootPhotoMode = .single
        let aspectRatio: DJICameraPhotoAspectRatio? = options.djiAspectRatio
        let quality: DJICameraPhotoQuality? = options.djiQuality
        
        // take the photo
        try self.takePhoto(cameraMode: cameraMode, shootMode: shootMode, aspectRatio: aspectRatio, quality: quality)
        
        // wait for the photo to appear and download it
        let photos: [DCKPhoto] = self.cameraDelegate.waitForAndDownloadPhotos(count: 1)
        guard let first = photos.first else {
            throw DJICameraTokenError.failedToDownloadMediaFromDrone
        }
        return first
    }
    
    public func takeHDRPhoto(options: Set<CameraPhotoOption>) throws -> DCKPhoto {
        let cameraMode: DJICameraMode = .shootPhoto
        let shootMode: DJICameraShootPhotoMode = .HDR
        let aspectRatio: DJICameraPhotoAspectRatio? = options.djiAspectRatio
        let quality: DJICameraPhotoQuality? = options.djiQuality
        
        // take the photo
        try self.takePhoto(cameraMode: cameraMode, shootMode: shootMode, aspectRatio: aspectRatio, quality: quality)
        
        // wait for the photo to appear and download it
        let photos: [DCKPhoto] = self.cameraDelegate.waitForAndDownloadPhotos(count: 1)
        guard let first = photos.first else {
            throw DJICameraTokenError.failedToDownloadMediaFromDrone
        }
        return first
    }
    
    public func takePhotoBurst(count: PhotoBurstCount, options: Set<CameraPhotoOption>) throws -> DCKPhotoBurst {
        let cameraMode: DJICameraMode = .shootPhoto
        let shootMode: DJICameraShootPhotoMode = .burst
        let aspectRatio: DJICameraPhotoAspectRatio? = options.djiAspectRatio
        let quality: DJICameraPhotoQuality? = options.djiQuality
        
        let unsignedCount: UInt = UInt(count.rawValue)
        
        guard let photoBurstCount: DJICameraPhotoBurstCount = DJICameraPhotoBurstCount(rawValue: unsignedCount) else {
            throw DJICameraTokenError.invalidPhotoBurstCountSpecified(count.rawValue)
        }
        
        // take the photo
        try self.takePhoto(cameraMode: cameraMode, shootMode: shootMode, interval: nil, burstCount: photoBurstCount, aspectRatio: aspectRatio, quality: quality)
        
        // wait for the photos to appear and download them
        let photos: [DCKPhoto] = self.cameraDelegate.waitForAndDownloadPhotos(count: count.rawValue)
        let burst = DCKPhotoBurst(photos: photos)
        return burst
    }
    
    public func startTakingPhotos(at interval: TimeInterval, options: Set<CameraPhotoOption>) throws {
        let cameraMode: DJICameraMode = .shootPhoto
        let shootMode: DJICameraShootPhotoMode = .interval
        let aspectRatio: DJICameraPhotoAspectRatio? = options.djiAspectRatio
        let quality: DJICameraPhotoQuality? = options.djiQuality
        
        // figure out the interval
        // a captureCount of 255 means the camera will continue taking photos until stopShootPhotoWithCompletion() is called
        let djiInterval = DJICameraPhotoIntervalParam(captureCount: 255, timeIntervalInSeconds: UInt16(interval))
        
        // take the photos
        try self.takePhoto(cameraMode: cameraMode, shootMode: shootMode, interval: djiInterval, burstCount: nil, aspectRatio: aspectRatio, quality: quality)
    }
    
    public func stopTakingPhotos() throws -> DCKPhotoBurst {
        // stop taking photos
        try self.stopPhotos()
        
        // wait 1 second for the photos to finish appearing and download them
        let photos: [DCKPhoto] = self.cameraDelegate.waitForAndDownloadPhotos(duration: 1.0)
        let burst = DCKPhotoBurst(photos: photos)
        return burst
    }
    
    public func startTimelapse(options: Set<CameraPhotoOption>) throws {
        let cameraMode: DJICameraMode = .shootPhoto
        let shootMode: DJICameraShootPhotoMode = .timeLapse
        let aspectRatio: DJICameraPhotoAspectRatio? = options.djiAspectRatio
        let quality: DJICameraPhotoQuality? = options.djiQuality
        
        // take the timelapse video
        try self.takePhoto(cameraMode: cameraMode, shootMode: shootMode, aspectRatio: aspectRatio, quality: quality)
    }
    
    public func stopTimelapse() throws -> DCKVideo {
        // stop the timelapse
        try self.stopPhotos()
        
        // wait for the video to appear and download it
        let videos: [DCKVideo] = self.cameraDelegate.waitForAndDownloadVideos(count: 1)
        guard let first = videos.first else {
            throw DJICameraTokenError.failedToDownloadMediaFromDrone
        }
        return first
    }
    
    public func startVideo(options: Set<CameraVideoOption>) {
        
    }
    
    public func stopVideo() -> DCKVideo {
        
    }
}

// MARK: - [CameraPhotoOption] Extensions

extension Sequence where Iterator.Element == CameraPhotoOption {
    var djiAspectRatio: DJICameraPhotoAspectRatio? {
        for option in self {
            if case .aspectRatio(let r) = option {
                return r.djiAspectRatio
            }
        }
        return nil
    }
    
    var djiQuality: DJICameraPhotoQuality? {
        for option in self {
            if case .quality(let q) = option {
                return q.djiQuality
            }
        }
        return nil
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
    case failedToDownloadMediaFromDrone
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
    
    // keep track of when we see new media files created on the drone
    var newPhotos: SynchronizedQueue<DJIMedia> = SynchronizedQueue<DJIMedia>()
    var newVideos: SynchronizedQueue<DJIMedia> = SynchronizedQueue<DJIMedia>()
    
    // used for converting DJIMedia timeCreated to Date()
    fileprivate lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        return formatter
    }()
    
    func waitForAndDownloadPhotos(count: Int) -> [DCKPhoto] {
        // sleep until we have all the photos we are expecting
        while newPhotos.count < count {
            Thread.sleep(forTimeInterval: 1)
        }
        
        // download them
        return self.downloadAllMediaFromQueue(queue: newPhotos, transformer: transformDJIMediaToDCKPhoto)
    }
    
    func waitForAndDownloadPhotos(duration: TimeInterval) -> [DCKPhoto] {
        // wait for the specified duration before downlodaing all the photos
        Thread.sleep(forTimeInterval: duration)
        
        // download them
        return self.downloadAllMediaFromQueue(queue: newPhotos, transformer: transformDJIMediaToDCKPhoto)
    }
    
    func waitForAndDownloadVideos(count: Int) -> [DCKVideo] {
        // sleep until we have the video we are expecting
        while newVideos.count < count {
            Thread.sleep(forTimeInterval: 1)
        }
        
        // download them
        return self.downloadAllMediaFromQueue(queue: newVideos, transformer: transformDJIMediaToDCKVideo)
    }
    
    fileprivate func downloadAllMediaFromQueue<T>(queue: SynchronizedQueue<DJIMedia>, transformer: @escaping ((DJIMedia, Data) -> T)) -> [T] {
        var downloaded: [T] = []
        
        while queue.count > 0 {
            // pop off the head
            guard let media = queue.dequeue() else { break }
            
            // download it
            let object = self.downloadObject(media: media, transformer: transformer)
            
            // add it to the return pile
            if let object = object {
                downloaded.append(object)
            }
        }
        
        return downloaded
    }
    
    fileprivate func downloadObject<T>(media: DJIMedia, transformer: @escaping ((DJIMedia, Data) -> T)) -> T? {
        var object: T?
        
        do {
            try DispatchQueue.executeSynchronously { asyncCompletionHandler in
                media.fetchData(completion: { (data: Data?, _: UnsafeMutablePointer<ObjCBool>?, error: Error?) in
                    
                    // wrap in the desired class
                    if let data = data {
                        object = transformer(media, data)
                    }
                    
                    // return
                    asyncCompletionHandler?(error)
                })
            }
        } catch let error {
            print("error downloading DJIMedia: \(error)")
        }
        
        return object
    }
    
    fileprivate func transformDJIMediaToDCKPhoto(media: DJIMedia, data: Data) -> DCKPhoto {
        let timeCreated = self.dateFormatter.date(from: media.timeCreated) ?? Date()
        
        return DCKPhoto(fileName: media.fileName, sizeInBytes: UInt(media.fileSizeInBytes), timeCreated: timeCreated, data: data, location: nil)
    }
    
    fileprivate func transformDJIMediaToDCKVideo(media: DJIMedia, data: Data) -> DCKVideo {
        let timeCreated = self.dateFormatter.date(from: media.timeCreated) ?? Date()
        
        return DCKVideo(fileName: media.fileName, sizeInBytes: UInt(media.fileSizeInBytes), timeCreated: timeCreated, durationInSeconds: Double(media.durationInSeconds), data: data)
    }
    
    // MARK: DJICameraDelegate
    
    func camera(_ camera: DJICamera, didUpdate ssdState: DJICameraSSDState) {
        self.ssdState = ssdState
    }
    
    func camera(_ camera: DJICamera, didUpdate lensState: DJICameraLensState) {
        self.lensState = lensState
    }
    
    func camera(_ camera: DJICamera, didGenerateNewMediaFile newMedia: DJIMedia) {
        // keep track of the file that was added
        switch newMedia.mediaType {
        case .JPEG, .RAWDNG, .TIFF:
            newPhotos.enqueue(newElement: newMedia)
        case .M4V, .MOV, .MP4:
            newVideos.enqueue(newElement: newMedia)
        case .panorama, .unknown: break
            // ignore, we don't support these
        }
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

// MARK: - SynchronizedQueue

public class SynchronizedQueue<T> {
    private var array: [T] = []
    private let accessQueue = DispatchQueue(label: "SynchronizedQueueAccess", attributes: .concurrent)
    
    public var count: Int {
        var count = 0
        
        self.accessQueue.sync {
            count = self.array.count
        }
        
        return count
    }
    
    public func enqueue(newElement: T) {
        self.accessQueue.async(flags: .barrier) {
            self.array.append(newElement)
        }
    }
    
    public func dequeue() -> T? {
        var element: T?
        
        self.accessQueue.async(flags: .barrier) {
            element = self.array.remove(at: 0)
        }
        
        return element
    }
}
