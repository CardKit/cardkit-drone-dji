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
import PromiseKit

//MARK: DJIGimbalToken

public class DJIGimbalToken: ExecutableTokenCard, GimbalToken {
    private let gimbal: DJIGimbal
    private let gimbalDelegate = GimbalDelegate()
    
    init(with card: TokenCard, for gimbal: DJIGimbal) {
        self.gimbal = gimbal
        self.gimbal.delegate = self.gimbalDelegate
        super.init(with: card)
    }
    
    //MARK: GimbalToken
    
    public func reset() -> Promise<Void> {
        return PromiseKit.wrap {
            self.gimbal.resetGimbal(completion: $0)
        }
    }
    
    public func rotateToAbsoluteAngle(pitch: Float, roll: Float, yaw: Float) -> Promise<Void> {
        let pitchAngle = DJIGimbalAngleRotation(enabled: true, angle: pitch, direction: .clockwise)
        let rollAngle = DJIGimbalAngleRotation(enabled: true, angle: roll, direction: .clockwise)
        let yawAngle = DJIGimbalAngleRotation(enabled: true, angle: yaw, direction: .clockwise)
        
        return PromiseKit.wrap {
            self.gimbal.rotateGimbal(with: .angleModeAbsoluteAngle, pitch: pitchAngle, roll: rollAngle, yaw: yawAngle, withCompletion: $0)
        }
    }
    
    public func rotateToRelativeAngle(pitch: Float, roll: Float, yaw: Float) -> Promise<Void> {
        let pitchAngle = DJIGimbalAngleRotation(enabled: true, angle: pitch, direction: .clockwise)
        let rollAngle = DJIGimbalAngleRotation(enabled: true, angle: roll, direction: .clockwise)
        let yawAngle = DJIGimbalAngleRotation(enabled: true, angle: yaw, direction: .clockwise)
        
        return PromiseKit.wrap {
            self.gimbal.rotateGimbal(with: .angleModeRelativeAngle, pitch: pitchAngle, roll: rollAngle, yaw: yawAngle, withCompletion: $0)
        }
    }
}

//MARK:- GimbalDelegate

// DJIFlightControllerDelegates must inherit from NSObject. We can't make DJIGimbalToken inherit from
// NSObject since it inherits from ExecutableTokenCard (which isn't an NSObject), so we use a private
// class for this instead.
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
