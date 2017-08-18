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
    
    // swiftlint:disable:next weak_delegate
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
        for (key, val) in self.gimbal.capabilities {
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
        try DispatchQueue.executeSynchronously { self.gimbal.startCalibration(completion: $0) }
        
        // wait for drone to start calibrating. this doesnt happen instantaneously. timeout after 5 seconds.
        var timeoutCount = 0
        while let isCalibrating = self.gimbalDelegate.currentState?.isCalibrating, !isCalibrating && timeoutCount < 5 {
            Thread.sleep(forTimeInterval: 1)
            timeoutCount += 1
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
    
    public func rotate(yaw: DCKAngle?, pitch: DCKAngle?, roll: DCKAngle?, relative: Bool, withinTimeInSeconds duration: Double?) throws {
        let rotationMode: DJIGimbalRotationMode = relative ? .relativeAngle : .absoluteAngle
        let duration = duration ?? 0.1
        let rotation = DJIGimbalRotation(pitchValue: pitch?.asNumber, rollValue: roll?.asNumber, yawValue: yaw?.asNumber, time: duration, mode: rotationMode)
        try DispatchQueue.executeSynchronously { self.gimbal.rotate(with: rotation, completion: $0) }
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
// swiftlint:disable:next private_over_fileprivate
fileprivate class GimbalDelegate: NSObject, DJIGimbalDelegate {
    var currentState: DJIGimbalState?
    var currentSettings: DJIGimbalMovementSettings?
    var currentGimbalBateryRemainingCharge: Int?
    
    func gimbal(_ gimbal: DJIGimbal, didUpdate gimbalState: DJIGimbalState) {
        self.currentState = gimbalState
    }
    
    func gimbal(_ gimbal: DJIGimbal, didUpdate movementSettings: DJIGimbalMovementSettings) {
        self.currentSettings = movementSettings
    }
    
    func gimbal(_ gimbal: DJIGimbal, didUpdateBatteryRemainingCharge charge: Int) {
        self.currentGimbalBateryRemainingCharge = charge
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

// swiftlint:disable:next private_over_fileprivate
fileprivate struct GimbalRotationRange {
    var axisEnabled: Bool
    var min: Double
    var max: Double
}
