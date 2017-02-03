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

public class DJIGimbalToken: ExecutableTokenCard, GimbalToken {
    private let gimbal: DJIGimbal
    
    //swiftlint:disable:next weak_delegate
    private let gimbalDelegate = GimbalDelegate()
    
    private var pitchRange: GimbalRotationRange
    private var rollRange: GimbalRotationRange
    private var yawRange: GimbalRotationRange
    
    init(with card: TokenCard, for gimbal: DJIGimbal) {
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
        
        print("yawRange: \(yawRange)")
        print("pitchRange: \(pitchRange)")
        print("rollRange: \(rollRange)")
        
        // set the gimbal work mode to Free
        self.gimbal.setGimbalWorkMode(.freeMode, withCompletion: { _ in
            print("error: could not set gimbal to Free mode")
        })
        
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
    
    public func calibrate(completionHandler: AsyncExecutionCompletionHandler?) {
        self.gimbal.startAutoCalibration(completion: { error in
            completionHandler?(error)
        })
    }
    
    public func reset(completionHandler: AsyncExecutionCompletionHandler?) {
        self.gimbal.resetGimbal(completion: { error in
            completionHandler?(error)
        })
    }
    
    //swiftlint:disable:next function_parameter_count
    public func rotate(yaw: DCKAngle?, pitch: DCKAngle?, roll: DCKAngle?, relativeToDrone: Bool, withinTimeInSeconds duration: Double?, completionHandler: AsyncExecutionCompletionHandler?) {
        let rotateAngleMode: DJIGimbalRotateAngleMode = relativeToDrone ? .angleModeRelativeAngle : .angleModeAbsoluteAngle
        
        var djiYaw: DJIGimbalAngleRotation = DJIGimbalAngleRotation(enabled: false, angle: 0, direction: .clockwise)
        var djiPitch: DJIGimbalAngleRotation = DJIGimbalAngleRotation(enabled: false, angle: 0, direction: .clockwise)
        var djiRoll: DJIGimbalAngleRotation = DJIGimbalAngleRotation(enabled: false, angle: 0, direction: .clockwise)
        
        if let yaw = yaw {
            djiYaw.enabled = ObjCBool(self.yawRange.axisEnabled)
            djiYaw.angle = relativeToDrone ? Float(yaw.degrees) : self.normalize(angle: yaw.degrees, to: self.yawRange)
        }
        
        if let pitch = pitch {
            djiPitch.enabled = ObjCBool(self.pitchRange.axisEnabled)
            djiPitch.angle = relativeToDrone ? Float(pitch.degrees) : self.normalize(angle: pitch.degrees, to: self.pitchRange)
        }
        
        if let roll = roll {
            djiRoll.enabled = ObjCBool(self.rollRange.axisEnabled)
            djiRoll.angle = relativeToDrone ? Float(roll.degrees) : self.normalize(angle: roll.degrees, to: self.rollRange)
        }
        
        // default to rotate as fast as possible
        self.gimbal.completionTimeForControlAngleAction = 0.1
        
        // range is [0.1, 25.5] seconds
        if let duration = duration {
            self.gimbal.completionTimeForControlAngleAction = clamp(value: duration, min: 0.1, max: 25.5)
        }
        
        print("djiYaw: \(djiYaw)")
        print("djiPitch: \(djiPitch)")
        print("djiRoll: \(djiRoll)")
        
        // rotate the gimbal
        self.gimbal.rotateGimbal(with: rotateAngleMode, pitch: djiPitch, roll: djiRoll, yaw: djiYaw, withCompletion: { error in
            completionHandler?(error)
        })
    }
    
    public func rotate(yaw: DCKAngularVelocity?, pitch: DCKAngularVelocity?, roll: DCKAngularVelocity?, forTimeInSeconds duration: Double, completionHandler: AsyncExecutionCompletionHandler?) {
        var djiYawSpeed: DJIGimbalSpeedRotation = DJIGimbalSpeedRotation(angleVelocity: 0, direction: .clockwise)
        var djiPitchSpeed: DJIGimbalSpeedRotation = DJIGimbalSpeedRotation(angleVelocity: 0, direction: .clockwise)
        var djiRollSpeed: DJIGimbalSpeedRotation = DJIGimbalSpeedRotation(angleVelocity: 0, direction: .clockwise)
        
        // gimbal rotation angular velocity is in degrees/second with a range of [0, 120]
        if let yaw = yaw {
            djiYawSpeed.angleVelocity = Float(clamp(value: yaw.degreesPerSecond, min: 0, max: 120))
            djiYawSpeed.direction = yaw.rotationDirection.djiRotateDirection
        }
        
        if let pitch = pitch {
            djiPitchSpeed.angleVelocity = Float(clamp(value: pitch.degreesPerSecond, min: 0, max: 120))
            djiPitchSpeed.direction = pitch.rotationDirection.djiRotateDirection
        }
        
        if let roll = roll {
            djiRollSpeed.angleVelocity = Float(clamp(value: roll.degreesPerSecond, min: 0, max: 120))
            djiRollSpeed.direction = roll.rotationDirection.djiRotateDirection
        }
        
        // range is [0.1, 25.5] seconds
        self.gimbal.completionTimeForControlAngleAction = clamp(value: duration, min: 0.1, max: 25.5)
        
        // rotate the gimbal
        self.gimbal.rotateGimbalBySpeed(withPitch: djiPitchSpeed, roll: djiRollSpeed, yaw: djiYawSpeed, withCompletion: { error in
            completionHandler?(error)
        })
    }
    
    public func orient(to position: GimbalOrientation, completionHandler: AsyncExecutionCompletionHandler?) {
        let yaw = DCKAngle(degrees: position.yawOrientationInDegrees)
        let pitch = DCKAngle(degrees: position.pitchOrientationInDegrees)
        let roll = DCKAngle(degrees: position.rollOrientationInDegrees)
        
        self.rotate(yaw: yaw, pitch: pitch, roll: roll, relativeToDrone: false, withinTimeInSeconds: nil, completionHandler: completionHandler)
    }
    
    /// Normalize the given angle to the given gimbal rotation range. The given angle is first normalized to the
    /// domain of [0, 360). Next it is clamped to the range [range.min, range.max].
    fileprivate func normalize(angle: Double, to range: GimbalRotationRange) -> Float {
        //We multiply by -1 as DJI represents angles in an inverted fashion
        //For example, DJI pitch ranges from [-90, 30]. -90 moves the gimbal down by 90 degrees.
        //We represent our rotation angles in the opposite mannner. Where moving the gimbal down 90 degrees
        //is represented with +90. See header doc for the rotate function for more details
    
        var normalizedAngle = DCKAngle(degrees: angle * -1).normalized().degrees
        
        if normalizedAngle > 180 {
            normalizedAngle -= 360
        }
        
        return Float(clamp(value: normalizedAngle, min: range.min, max: range.max))
    }
    
    /// Returns the absolute angle; e.g. negative angles (-90) are returned as positive ones (270).
    /// Angles outside the range of [0, 360) (e.g. 1080) are normalized to fall within the range.
    fileprivate func absoluteAngle(angle: Double) -> Double {
        var circularAngle = angle.truncatingRemainder(dividingBy: 360)
        if circularAngle < 0 {
            circularAngle = 360 - (-circularAngle)
        }
        return circularAngle
    }
    
    /// Clamp the given value to the range; values that fall below the range are held at the minimum,
    /// and values that fall above the range are held at the maximu.
    fileprivate func clamp(value: Double, min: Double, max: Double) -> Double {
        if value < min { return min }
        if value > max { return max }
        return value
    }
}

// MARK: - GimbalDelegate

/// DJIFlightControllerDelegates must inherit from NSObject. We can't make DJIGimbalToken inherit from
/// NSObject since it inherits from ExecutableTokenCard (which isn't an NSObject), so we use a private
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
        switch self {
        case .clockwise:
            return .clockwise
        case .counterClockwise:
            return .counterClockwise
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
            return 90.0
        case .facingDownward:
            return 0.0
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
