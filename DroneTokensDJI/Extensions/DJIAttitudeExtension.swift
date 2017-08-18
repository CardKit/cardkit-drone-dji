//
//  DJIAttitudeExtension.swift
//  DroneTokensDJI
//
//  Created by ismails on 2/1/17.
//  Copyright © 2017 IBM. All rights reserved.
//

import Foundation

import DJISDK

extension DJIAttitude {
    /// Normalizes the attitude (yaw, pitch, roll) from a range of [-180, 180] to the range [0, 360].
    /// A yaw, pitch, and roll of (0, 0, 0) corresponds to an aircraft hovering level oriented toward True North.
    func normalized() -> DJIAttitude {
        let normalizedYaw = (yaw + 360).truncatingRemainder(dividingBy: 360)
        let normalizedPitch = (pitch + 360).truncatingRemainder(dividingBy: 360)
        let normalizedRoll = (roll + 360).truncatingRemainder(dividingBy: 360)
        
        return DJIAttitude(pitch: normalizedPitch, roll: normalizedRoll, yaw: normalizedYaw)
    }
}
