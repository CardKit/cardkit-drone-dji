//
//  DJIGimbalToken.swift
//  DroneCardKit
//
//  Created by Justin Weisz on 11/29/16.
//  Copyright © 2016 IBM. All rights reserved.
//

import Foundation

import CardKit
import CardKitRuntime
import DroneCardKit

import DJISDK

public class DJIGimbalToken: ExecutableToken, GimbalToken {
    private let gimbal: DJIGimbal
    
    //swiftlint:disable:next weak_delegate
    private let gimbalDelegate = GimbalDelegate()
    
    private var pitchRange: GimbalRotationRange
    private var rollRange: GimbalRotationRange
    private var yawRange: GimbalRotationRange
    
    public init(with card: TokenCard, for gimbal: DJIGimbal) {
        self.gimbal = gimbal
        self.gimbal.delegate = self.gimbalDelegate
        
        // default is that the gimbal cannot move
        pitchRange = GimbalRotationRange(axisEnabled: false, min: 0, max: 0)
        rollRange = GimbalRotationRange(axisEnabled: false, min: 0, max: 0)
        yawRange = GimbalRotationRange(axisEnabled: false, min: 0, max: 0)
        
        // figure out the [min, max] range of the gimbal's motion for each axis
        for (key, val) in self.gimbal.gimbalCapability {
            guard let strKey = key as? String else { break }
            switch strKey {
            case "AdjustPitch":
                guard let minMax = val as? DJIParamCapabilityMinMax else { break }
                pitchRange.axisEnabled = minMax.isSupported
                pitchRange.min = minMax.min.doubleValue
                pitchRange.max = minMax.max.doubleValue
            case "AdjustRoll":
                guard let minMax = val as? DJIParamCapabilityMinMax else { break }
                rollRange.axisEnabled = minMax.isSupported
                rollRange.min = minMax.min.doubleValue
                rollRange.max = minMax.max.doubleValue
            case "AdjustYaw":
                guard let minMax = val as? DJIParamCapabilityMinMax else { break }
                yawRange.axisEnabled = minMax.isSupported
                yawRange.min = minMax.min.doubleValue
                yawRange.max = minMax.max.doubleValue
            default:
                break
            }
        }
        
        super.init(with: card)
    }
    
    // MARK: GimbalToken
    
    public var currentAttitude: DCKAttitude? {
        guard let gimbalAttitude = self.gimbalDelegate.currentState?.attitudeInDegrees else { return nil }
        let yaw = DCKAngle(degrees: Double(gimbalAttitude.yaw))
        let pitch = DCKAngle(degrees: Double(gimbalAttitude.pitch))
        let roll = DCKAngle(degrees: Double(gimbalAttitude.roll))
        let attitude = DCKAttitude(yaw: yaw, pitch: pitch, roll: roll)
        return attitude
    }
    
    public func calibrate() throws {
        try DispatchQueue.executeSynchronously { self.gimbal.startAutoCalibration(completion: $0) }
        
        var timeoutCount = 0
        
        // wait for drone to start calibrating. this doesnt happen instantaneously. timeout after 5 seconds.
        while let isCalibrating = self.gimbalDelegate.currentState?.isCalibrating, !isCalibrating && timeoutCount < 5 {
            Thread.sleep(forTimeInterval: 1)
            timeoutCount+=1
        }
        
        if let isCalibrating = self.gimbalDelegate.currentState?.isCalibrating, timeoutCount == 5 && !isCalibrating {
            throw GimbalTokenError.failedToBeginCalibration
        }
        
        // wait for the drone to finish calibrating
        while let isCalibrating = self.gimbalDelegate.currentState?.isCalibrating, isCalibrating {
            Thread.sleep(forTimeInterval: 3)
        }
    }
    
    public func reset() throws {
        let zero = DCKAngle(degrees: 0)
        try self.rotate(yaw: zero, pitch: zero, roll: zero, relativeToDrone: false, withinTimeInSeconds: 1)
    }
    
    //swiftlint:disable:next function_parameter_count
    public func rotate(yaw: DCKAngle?, pitch: DCKAngle?, roll: DCKAngle?, relativeToDrone: Bool, withinTimeInSeconds duration: Double?) throws {
        let rotateAngleMode: DJIGimbalRotateAngleMode = relativeToDrone ? .angleModeRelativeAngle : .angleModeAbsoluteAngle
        
        var djiYaw: DJIGimbalAngleRotation = DJIGimbalAngleRotation(enabled: false, angle: 0, direction: .clockwise)
        var djiPitch: DJIGimbalAngleRotation = DJIGimbalAngleRotation(enabled: false, angle: 0, direction: .clockwise)
        var djiRoll: DJIGimbalAngleRotation = DJIGimbalAngleRotation(enabled: false, angle: 0, direction: .clockwise)
        
        if let yaw = yaw {
            djiYaw.enabled = ObjCBool(self.yawRange.axisEnabled)
            djiYaw.angle = relativeToDrone ? self.normalizeRelativeAngle(yaw.degrees) : self.normalizeAbsoluteAngle(yaw.degrees, to: self.yawRange)
        }
        
        if let pitch = pitch {
            djiPitch.enabled = ObjCBool(self.pitchRange.axisEnabled)
            djiPitch.angle = relativeToDrone ? self.normalizeRelativeAngle(pitch.degrees) : self.normalizeAbsoluteAngle(pitch.degrees, to: self.pitchRange)
        }
        
        if let roll = roll {
            djiRoll.enabled = ObjCBool(self.rollRange.axisEnabled)
            djiRoll.angle = relativeToDrone ? self.normalizeRelativeAngle(roll.degrees) : self.normalizeAbsoluteAngle(roll.degrees, to: self.rollRange)
        }
        
        // default to rotate as fast as possible
        self.gimbal.completionTimeForControlAngleAction = 0.1
        
        // range is [0.1, 25.5] seconds
        if let duration = duration {
            self.gimbal.completionTimeForControlAngleAction = Double(clamp(value: duration, min: 0.1, max: 25.5))
        }
        
        // start rotating the gimbal
        try DispatchQueue.executeSynchronously { self.gimbal.rotateGimbal(with: rotateAngleMode, pitch: djiPitch, roll: djiRoll, yaw: djiYaw, withCompletion: $0) }
        
        //wait until the gimbal finishes rotating
        Thread.sleep(forTimeInterval: self.gimbal.completionTimeForControlAngleAction)
    }
    
    public func rotate(yaw: DCKAngularVelocity?, pitch: DCKAngularVelocity?, roll: DCKAngularVelocity?, forTimeInSeconds duration: Double) throws {
        var djiYawSpeed: DJIGimbalSpeedRotation = DJIGimbalSpeedRotation(angleVelocity: 0, direction: .clockwise)
        var djiPitchSpeed: DJIGimbalSpeedRotation = DJIGimbalSpeedRotation(angleVelocity: 0, direction: .clockwise)
        var djiRollSpeed: DJIGimbalSpeedRotation = DJIGimbalSpeedRotation(angleVelocity: 0, direction: .clockwise)
        
        // gimbal rotation angular velocity is in degrees/second with a range of [0, 120]
        if let yaw = yaw {
            djiYawSpeed.angleVelocity = clamp(value: abs(yaw.degreesPerSecond), min: 0, max: 120)
            djiYawSpeed.direction = yaw.rotationDirection.djiRotateDirection
        }
        
        if let pitch = pitch {
            djiPitchSpeed.angleVelocity = clamp(value: abs(pitch.degreesPerSecond), min: 0, max: 120)
            djiPitchSpeed.direction = pitch.rotationDirection.djiRotateDirection
        }
        
        if let roll = roll {
            djiRollSpeed.angleVelocity = clamp(value: abs(roll.degreesPerSecond), min: 0, max: 120)
            djiRollSpeed.direction = roll.rotationDirection.djiRotateDirection
        }
        
        let startDateTime = Date()
        var endDateTime = Date()
        
        if let endDate = Calendar.current.date(byAdding: .second, value: Int(duration), to: startDateTime) {
            endDateTime = endDate
        }
        
        try DispatchQueue.executeSynchronously { self.rotateContinouslyBySpeed(yaw: djiYawSpeed, pitch: djiPitchSpeed, roll: djiRollSpeed, endDateTime: endDateTime, completionHandler: $0, completionHandlerState: CompletionHandlerState()) }
    }
    
    //swiftlint:disable:next function_parameter_count
    /// To rotate with angular velocity, we need to continously call the `rotateGimbalBySpeed()` command (every 100 milliseconds)
    /// This is not documented anywhere. Of course :/ It's used in this way in the android sample app:
    /// https://github.com/dji-sdk/Mobile-SDK-Android/blob/master/Sample%20Code/app/src/main/java/com/dji/sdk/sample/gimbal/MoveGimbalWithSpeedView.java
    ///
    /// In this function we call rotateContinouslyBySpeed() every 100ms. We also call `rotateGimbalBySpeed()` to actually rotate
    /// the gimbal. When the gimbal has completed rotating (for some period of time.. this is not documented), we check to see if 
    /// the competion handler has already been called. If it has not been called, we check to see if we should stop rotation or if there was an error while rotating. If so, we call the completionHandler.
    private func rotateContinouslyBySpeed(yaw: DJIGimbalSpeedRotation,
                                          pitch: DJIGimbalSpeedRotation,
                                          roll: DJIGimbalSpeedRotation,
                                          endDateTime: Date,
                                          completionHandler: AsyncExecutionCompletionHandler?,
                                          completionHandlerState: CompletionHandlerState) {
        
        self.gimbal.rotateGimbalBySpeed(withPitch: pitch, roll: roll, yaw: yaw, withCompletion: { error in
            if !completionHandlerState.wasCalled && (Date() > endDateTime || error != nil) {
                completionHandlerState.wasCalled = true
                completionHandler?(error)
            }
        })
        
        if !completionHandlerState.wasCalled && Date() < endDateTime {
            let deadlineTime = DispatchTime.now() + .milliseconds(100)
            DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
                self.rotateContinouslyBySpeed(yaw: yaw, pitch: pitch, roll: roll, endDateTime: endDateTime, completionHandler: completionHandler, completionHandlerState: completionHandlerState)
            }
        }
    }
    
    public func orient(to position: GimbalOrientation) throws {
        let yaw = DCKAngle(degrees: position.yawOrientationInDegrees)
        let pitch = DCKAngle(degrees: position.pitchOrientationInDegrees)
        let roll = DCKAngle(degrees: position.rollOrientationInDegrees)
        
        try self.rotate(yaw: yaw, pitch: pitch, roll: roll, relativeToDrone: false, withinTimeInSeconds: nil)
    }
    
    /// Normalize the given angle to the given gimbal rotation range. The given angle is first normalized to the
    /// domain of [0, 360). Next it is clamped to the range [range.min, range.max].
    fileprivate func normalizeAbsoluteAngle(_ angle: Double, to range: GimbalRotationRange) -> Float {
        //We multiply by -1 as DJI represents angles in an inverted fashion
        //For example, DJI pitch ranges from [-90, 30]. -90 moves the gimbal down by 90 degrees.
        //We represent our rotation angles in the opposite mannner. Where moving the gimbal down 90 degrees
        //is represented with +90. See header doc for the rotate function for more details
        
        var normalizedAngle = DCKAngle(degrees: angle * -1).normalized().degrees
        
        if normalizedAngle > 180 {
            normalizedAngle -= 360
        }
        
        return clamp(value: normalizedAngle, min: range.min, max: range.max)
    }
    
    /// We multiply by the relative angle by -1 as DJI represents angles inverted
    fileprivate func normalizeRelativeAngle(_ angle: Double) -> Float {
        return Float(-1*angle)
    }
    
    /// Clamp the given value to the range; values that fall below the range are held at the minimum,
    /// and values that fall above the range are held at the maximu.
    fileprivate func clamp(value: Double, min: Double, max: Double) -> Float {
        if value < min { return Float(min) }
        if value > max { return Float(max) }
        return Float(value)
    }
}

// MARK: - GimbalDelegate

/// DJIFlightControllerDelegates must inherit from NSObject. We can't make DJIGimbalToken inherit from
/// NSObject since it inherits from ExecutableToken (which isn't an NSObject), so we use a private
/// class for this instead.
fileprivate class GimbalDelegate: NSObject, DJIGimbalDelegate {
    var currentState: DJIGimbalState?
    var currentSettings: DJIGimbalAdvancedSettingsState?
    var currentGimbalBateryEnergy: Int?
    
    func gimbal(_ gimbal: DJIGimbal, didUpdate gimbalState: DJIGimbalState) {
        self.currentState = gimbalState
    }
    
    func gimbal(_ gimbal: DJIGimbal, didUpdate settingsState: DJIGimbalAdvancedSettingsState) {
        self.currentSettings = settingsState
    }
    
    func gimbal(_ gimbal: DJIGimbal, didUpdateGimbalBatteryRemainingEnergy energy: Int) {
        self.currentGimbalBateryEnergy = energy
    }
}

// MARK: - DCKRotationDirection Extensions

extension DCKRotationDirection {
    var djiRotateDirection: DJIGimbalRotateDirection {
        // This is reversed because DJI handles the rotation direction in an inverted manner
        // For example, -10 degrees is specified as counterclockwise in our api where as
        // it would be clockwise for DJI
        
        switch self {
        case .clockwise:
            return .counterClockwise
        case .counterClockwise:
            return .clockwise
        }
    }
}

// MARK: - GimbalOrientation Extensions

extension GimbalOrientation {
    var yawOrientationInDegrees: Double {
        return 0.0
    }
    
    var pitchOrientationInDegrees: Double {
        switch self {
        case .facingForward:
            return 0.0
        case .facingDownward:
            return 90.0
        }
    }
    
    var rollOrientationInDegrees: Double {
        return 0.0
    }
}

// MARK: - GimbalRotationRange

fileprivate struct GimbalRotationRange {
    var axisEnabled: Bool
    var min: Double
    var max: Double
}

// MARK: - CompletionHandlerState

/// Class that keeps track of whether or not the completion handler has been called
fileprivate class CompletionHandlerState {
    var wasCalled = false
}
