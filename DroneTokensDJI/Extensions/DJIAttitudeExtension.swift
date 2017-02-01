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
    func normalized() -> DJIAttitude {
        // From DJI Documentation
        // Attitude of the aircraft where the pitch, roll, and yaw values will be in the range of [-180, 180]. If the values of the pitch, roll, and yaw are 0, the aircraft will be hovering level with a True North heading.
        
        let normalizedYaw = (yaw + 360).truncatingRemainder(dividingBy: 360)
        let normalizedPitch = (pitch + 360).truncatingRemainder(dividingBy: 360)
        let normalizedRoll = (roll + 360).truncatingRemainder(dividingBy: 360)
        
        return DJIAttitude(pitch: normalizedPitch, roll: normalizedRoll, yaw: normalizedYaw)
    }
}
