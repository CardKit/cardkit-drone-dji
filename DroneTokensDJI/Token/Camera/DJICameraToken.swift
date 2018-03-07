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

import Foundation

import CardKit
import CardKitRuntime
import DroneCardKit

import DJISDK

// MARK: DJICameraToken

public class DJICameraToken: ExecutableToken {
    private let camera: DJICamera
    
    // swiftlint:disable:next weak_delegate
    fileprivate let cameraDelegate: CameraDelegate = CameraDelegate()
    
    public init(with card: TokenCard, for camera: DJICamera) {
        self.camera = camera
        camera.delegate = self.cameraDelegate
        super.init(with: card)
    }
    
    func takePhoto(cameraMode: DJICameraMode, shootMode: DJICameraShootPhotoMode, aspectRatio: DJICameraPhotoAspectRatio?) throws {
        try self.takePhoto(cameraMode: cameraMode, shootMode: shootMode, interval: nil, burstCount: nil, aspectRatio: aspectRatio)
    }
    
    func takePhoto(cameraMode: DJICameraMode, shootMode: DJICameraShootPhotoMode, interval: DJICameraPhotoTimeIntervalSettings?, burstCount: DJICameraPhotoBurstCount?, aspectRatio: DJICameraPhotoAspectRatio?) throws {
        
        // set the camera mode
        do {
            try DispatchQueue.executeSynchronously { self.camera.setMode(cameraMode, withCompletion: $0) }
        } catch {
            throw error
        }
        
        // make sure there is enough space on the SD card
        guard let sdState = self.cameraDelegate.sdCardState else {
            throw DJICameraTokenError.failedToObtainSDCardState
        }
        
        if sdState.availableCaptureCount <= 0 {
            throw DJICameraTokenError.sdCardFull
        }
        
        // set the shoot mode
        try DispatchQueue.executeSynchronously { self.camera.setShootPhotoMode(shootMode, withCompletion: $0) }
        
        // set the aspect ratio
        if let aspectRatio = aspectRatio {
            try DispatchQueue.executeSynchronously { self.camera.setPhotoAspectRatio(aspectRatio, withCompletion: $0) }
        }
        
        // set the burstCount (if we're taking photos in burst mode)
        if shootMode == .burst, let burstCount = burstCount {
            do {
                try DispatchQueue.executeSynchronously { self.camera.setPhotoBurstCount(burstCount, withCompletion: $0) }
            } catch let error {
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
            try DispatchQueue.executeSynchronously { self.camera.setPhotoTimeIntervalSettings(interval, withCompletion: $0) }
        }
        
        // take the photo
        try DispatchQueue.executeSynchronously { self.camera.startShootPhoto(completion: $0) }
    }
    
    func stopPhotos() throws {
        try DispatchQueue.executeSynchronously { self.camera.stopShootPhoto(completion: $0) }
    }
    
    func recordVideo(cameraMode: DJICameraMode, framerate: DJICameraVideoFrameRate?, resolution: DJICameraVideoResolution?) throws {
        try DispatchQueue.executeSynchronously { self.camera.setMode(cameraMode, withCompletion: $0) }
        
        if let framerate = framerate, let resolution = resolution {
            let resolutionAndFramerate = DJICameraVideoResolutionAndFrameRate(resolution: resolution, frameRate: framerate)
            try DispatchQueue.executeSynchronously { self.camera.setVideoResolutionAndFrameRate(resolutionAndFramerate, withCompletion: $0) }
        }
        
        try DispatchQueue.executeSynchronously { self.camera.startRecordVideo(completion: $0) }
        
        // the startRecordVideo callback does not coincide with the actual system state changing to recording;
        // RunLoop similarly prevents the system state from updating
        while self.cameraDelegate.systemState?.isRecording == false {}
    }
    
    func stopRecordVideo() throws {
        try DispatchQueue.executeSynchronously { self.camera.stopRecordVideo(completion: $0)}
        
        // the stopRecordVideo callback does not coincide with the actual system state changing to not recording;
        // for some reason RunLoop is non-blocking here
        while self.cameraDelegate.systemState?.isRecording == true {
            RunLoop.current.run(mode: .defaultRunLoopMode, before: Date.distantFuture)
        }
    }
}

// MARK: CameraToken Protocol

extension DJICameraToken: CameraToken {
    public func takePhoto(options: Set<CameraPhotoOption>) throws -> DCKPhoto {
        let cameraMode: DJICameraMode = .shootPhoto
        let shootMode: DJICameraShootPhotoMode = .single
        let aspectRatio: DJICameraPhotoAspectRatio? = options.djiAspectRatio
        
        // take the photo
        try self.takePhoto(cameraMode: cameraMode, shootMode: shootMode, aspectRatio: aspectRatio)
        
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
        
        // take the photo
        try self.takePhoto(cameraMode: cameraMode, shootMode: shootMode, aspectRatio: aspectRatio)
        
        // wait for the photo to appear and download it
        let photos: [DCKPhoto] = self.cameraDelegate.waitForAndDownloadPhotos(count: 1)
        guard let first = photos.first else {
            throw DJICameraTokenError.failedToDownloadMediaFromDrone
        }
        return first
    }
    
    public func takePhotoBurst(count: DCKPhotoBurstCount, options: Set<CameraPhotoOption>) throws -> DCKPhotoBurst {
        let cameraMode: DJICameraMode = .shootPhoto
        let shootMode: DJICameraShootPhotoMode = .burst
        let aspectRatio: DJICameraPhotoAspectRatio? = options.djiAspectRatio
        
        let unsignedCount: UInt = UInt(count.rawValue)
        
        guard let photoBurstCount: DJICameraPhotoBurstCount = DJICameraPhotoBurstCount(rawValue: unsignedCount) else {
            throw DJICameraTokenError.invalidPhotoBurstCountSpecified(count.rawValue)
        }
        
        // take the photo
        try self.takePhoto(cameraMode: cameraMode, shootMode: shootMode, interval: nil, burstCount: photoBurstCount, aspectRatio: aspectRatio)
        
        // wait for the photos to appear and download them
        let photos: [DCKPhoto] = self.cameraDelegate.waitForAndDownloadPhotos(count: count.rawValue)
        let burst = DCKPhotoBurst(photos: photos)
        return burst
    }
    
    public func startTakingPhotos(at interval: TimeInterval, options: Set<CameraPhotoOption>) throws {
        let cameraMode: DJICameraMode = .shootPhoto
        let shootMode: DJICameraShootPhotoMode = .interval
        let aspectRatio: DJICameraPhotoAspectRatio? = options.djiAspectRatio
        
        // figure out the interval
        // a captureCount of 255 means the camera will continue taking photos until stopShootPhotoWithCompletion() is called
        let djiInterval = DJICameraPhotoTimeIntervalSettings(captureCount: 255, timeIntervalInSeconds: UInt16(interval))
        
        // take the photos
        try self.takePhoto(cameraMode: cameraMode, shootMode: shootMode, interval: djiInterval, burstCount: nil, aspectRatio: aspectRatio)
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
        
        // take the timelapse video
        try self.takePhoto(cameraMode: cameraMode, shootMode: shootMode, aspectRatio: aspectRatio)
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
    
    public func startVideo(options: Set<CameraVideoOption>) throws {
        let cameraMode: DJICameraMode = .recordVideo
        let framerate: DJICameraVideoFrameRate? = options.djiVideoFrameRate
        let resolution: DJICameraVideoResolution? = options.djiVideoResolution
        
        try self.recordVideo(cameraMode: cameraMode, framerate: framerate, resolution: resolution)
    }
    
    public func stopVideo() throws -> DCKVideo {
        // stop the video recording
        try self.stopRecordVideo()
        
        // wait for the video to appear and download it
        let videos: [DCKVideo] = self.cameraDelegate.waitForAndDownloadVideos(count: 1)
        guard let first = videos.first else {
            throw DJICameraTokenError.failedToDownloadMediaFromDrone
        }
        return first
    }
}

// MARK: - DJICameraTokenError

public enum DJICameraTokenError: Error {
    case failedToObtainSDCardState
    case sdCardFull
    case invalidPhotoBurstCountSpecified(Int)
    case failedToDownloadMediaFromDrone
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
}

// MARK: - [CameraVideoOption] Extensions

extension Sequence where Iterator.Element == CameraVideoOption {
    var djiVideoFrameRate: DJICameraVideoFrameRate? {
        for option in self {
            if case .framerate(let f) = option {
                return f.djiVideoFrameRate
            }
        }
        return nil
    }
    
    var djiVideoResolution: DJICameraVideoResolution? {
        for option in self {
            if case .resolution(let r) = option {
                return r.djiVideoResolution
            }
        }
        return nil
    }
}

// MARK: - DCKPhotoAspectRatio Extensions

extension DCKPhotoAspectRatio {
    var djiAspectRatio: DJICameraPhotoAspectRatio {
        switch self {
        case .aspect16x9:
            return .ratio16_9
        case .aspect3x2:
            return .ratio3_2
        case .aspect4x3:
            return .ratio4_3
        }
    }
}

// MARK: - DCKVideoFrameRate Extensions

extension DCKVideoFramerate {
    var djiVideoFrameRate: DJICameraVideoFrameRate {
        switch self {
        case .framerate23dot976fps:
            return .rate23dot976FPS
        case .framerate24fps:
            return .rate24FPS
        case .framerate25fps:
            return .rate25FPS
        case .framerate29dot970fps:
            return .rate29dot970FPS
        case .framerate30fps:
            return .rate29dot970FPS
        case .framerate47dot950fps:
            return .rate47dot950FPS
        case .framerate48fps:
            return .rate47dot950FPS
        case .framerate50fps:
            return .rate50FPS
        case .framerate59dot940fps:
            return .rate59dot940FPS
        case .framerate60fps:
            return .rate59dot940FPS
        case .framerate96fps:
            return .rate96FPS
        case .framerate120fps:
            return .rate120FPS
        case .unknown:
            return .rateUnknown
        }
    }
}

// MARK: - DCKVideoResolution Extensions

extension DCKVideoResolution {
    var djiVideoResolution: DJICameraVideoResolution {
        switch self {
        case .resolution640x480:
            return .resolution640x480
        case .resolution640x512:
            return .resolution640x512
        case .resolution720p:
            return .resolution1280x720
        case .resolution1080p:
            return .resolution1920x1080
        case .resolution2704x1520:
            return .resolution2704x1520
        case .resolution2720x1530:
            return .resolution2720x1530
        case .resolution3840x1572:
            return .resolution3840x1572
        case .resolution4k:
            return .resolution3840x2160
        case .resolution4096x2160:
            return .resolution4096x2160
        case .resolution5280x2160:
            return .resolution5280x2160
        case .max:
            return .resolutionMax
        case .noSSDVideo:
            return .resolutionNoSSDVideo
        case .unknown:
            return .resolutionUnknown
        }
    }
}

// MARK: - DCKPhotoBurstCount Extensions

extension DCKPhotoBurstCount {
    var djiPhotoBurstCount: DJICameraPhotoBurstCount {
        switch self {
        case .burst3:
            return .count3
        case .burst5:
            return .count5
        case .burst7:
            return .count7
        case .burst10:
            return .count10
        case .burst14:
            return .count14
        }
    }
}

// MARK: - CameraDelegate

// DJICameraDelegates must inherit from NSObject. We can't make DJICameraToken inherit from
// NSObject since it inherits from ExecutableToken (which isn't an NSObject), so we use a private
// class for this instead.
// swiftlint:disable:next private_over_fileprivate
fileprivate class CameraDelegate: NSObject, DJICameraDelegate {
    var sdCardState: DJICameraSDCardState?
    var ssdState: DJICameraSSDState?
    var systemState: DJICameraSystemState?
    
    // keep track of when we see new media files created on the drone
    var newPhotos: SynchronizedQueue<DJIMediaFile> = SynchronizedQueue<DJIMediaFile>()
    var newVideos: SynchronizedQueue<DJIMediaFile> = SynchronizedQueue<DJIMediaFile>()
    
    // used for converting DJIMedia timeCreated to Date()
    fileprivate lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        return formatter
    }()
    
    // wait for up to N seconds for new media to appear before timing out and just returning
    // what we have
    fileprivate let mediaAppearanceTimeout: TimeInterval = 10
    
    func waitForAndDownloadPhotos(count: Int) -> [DCKPhoto] {
        let endTime = Date(timeIntervalSinceNow: mediaAppearanceTimeout)
        
        // sleep until we have all the photos we are expecting
        while newPhotos.count < count && Date() < endTime {
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
        let endTime = Date(timeIntervalSinceNow: mediaAppearanceTimeout)
        
        // sleep until we have the video we are expecting
        while newVideos.count < count && Date() < endTime {
            Thread.sleep(forTimeInterval: 1)
        }
        
        // download them
        return self.downloadAllMediaFromQueue(queue: newVideos, transformer: transformDJIMediaToDCKVideo)
    }
    
    fileprivate func downloadAllMediaFromQueue<T>(queue: SynchronizedQueue<DJIMediaFile>, transformer: @escaping ((DJIMediaFile, Data) -> T)) -> [T] {
        var downloaded: [T] = []
        
        while queue.count > 0 {
            // pop off the head
            guard let media = queue.dequeue() else { break }
            
            // download it
            let object = self.downloadMediaFile(media: media, transformer: transformer)
            
            // add it to the return pile
            if let object = object {
                downloaded.append(object)
            }
        }
        
        return downloaded
    }
    
    fileprivate func downloadMediaFile<T>(media: DJIMediaFile, transformer: @escaping ((DJIMediaFile, Data) -> T)) -> T? {
        var object: T? = nil
        var mediaFileData: Data = Data()
        
        do {
            try DispatchQueue.executeSynchronously { asyncCompletionHandler in
                let queue = DispatchQueue(label: "DJIMediaFile fetchData")
                media.fetchData(withOffset: 0, update: queue, update: { data, isComplete, error in
                    // if there was an error, bail
                    if let error = error {
                        object = nil
                        asyncCompletionHandler?(error)
                    }
                    
                    // data is the next chunk of data read from the file, append it to the buffer
                    if let data = data {
                        mediaFileData.append(data)
                    }
                    
                    // if the download has completed, transform the media file into the requested object type
                    // (e.g. DCKPhoto or DCKVideo) and return
                    if isComplete {
                        object = transformer(media, mediaFileData)
                        asyncCompletionHandler?(error)
                    }
                })
            }
        } catch let error {
            print("error downloading DJIMediaFile: \(error)")
        }
        
        return object
    }
    
    fileprivate func transformDJIMediaToDCKPhoto(media: DJIMediaFile, data: Data) -> DCKPhoto {
        let timeCreated = self.dateFormatter.date(from: media.timeCreated) ?? Date()
        
        return DCKPhoto(fileName: media.fileName, sizeInBytes: UInt(media.fileSizeInBytes), timeCreated: timeCreated, data: data, location: nil)
    }
    
    fileprivate func transformDJIMediaToDCKVideo(media: DJIMediaFile, data: Data) -> DCKVideo {
        let timeCreated = self.dateFormatter.date(from: media.timeCreated) ?? Date()
        
        return DCKVideo(fileName: media.fileName, sizeInBytes: UInt(media.fileSizeInBytes), timeCreated: timeCreated, durationInSeconds: Double(media.durationInSeconds), data: data)
    }
    
    // MARK: DJICameraDelegate
    
    func camera(_ camera: DJICamera, didUpdate systemState: DJICameraSystemState) {
        //        print("SYSTEM STATE CHANGED isShootingInterval:\(systemState.isShootingIntervalPhoto)")
        //        print("SYSTEM STATE CHANGED isRecording:\(systemState.isRecording)")
        //        print("SYSTEM STATE CHANGED isCameraOverHeated:\(systemState.isCameraOverHeated)")
        //        print("SYSTEM STATE CHANGED isCameraError:\(systemState.isCameraError)")
        self.systemState = systemState
    }
    
    func camera(_ camera: DJICamera, didUpdate focusState: DJICameraFocusState) {
        
    }
    
    func camera(_ camera: DJICamera, didGenerateNewMediaFile newMedia: DJIMediaFile) {
        // keep track of the file that was added
        switch newMedia.mediaType {
        case .JPEG, .RAWDNG, .TIFF:
            newPhotos.enqueue(newElement: newMedia)
        case .MOV, .MP4:
            newVideos.enqueue(newElement: newMedia)
        case .panorama, .shallowFocus, .unknown:
            // ignore, we don't support these
            break
        }
    }
    
    func camera(_ camera: DJICamera, didGenerateTimeLapsePreview previewImage: UIImage) {
        // tbd
    }
    
    func camera(_ camera: DJICamera, didUpdate sdCardState: DJICameraSDCardState) {
        self.sdCardState = sdCardState
    }
    
    func camera(_ camera: DJICamera, didUpdate ssdState: DJICameraSSDState) {
        self.ssdState = ssdState
    }
    
    func camera(_ camera: DJICamera, didUpdate temperatureAggregations: DJICameraThermalAreaTemperatureAggregations) {
        // tbd
    }
    
    func camera(_ camera: DJICamera, didUpdate externalSceneSettings: DJICameraThermalExternalSceneSettings) {
        // tbd
    }
    
    func camera(_ camera: DJICamera, didUpdate exposureSettings: DJICameraExposureSettings) {
        // tbd
    }
    
    func camera(_ camera: DJICamera, didUpdateTemperatureData temperature: Float) {
        // tbd
    }
}

// MARK: - SynchronizedQueue

// swiftlint:disable:next private_over_fileprivate
fileprivate class SynchronizedQueue<T> {
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
