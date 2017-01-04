//
//  DummyDroneToken.swift
//  DroneCardKit
//
//  Created by ismails on 12/9/16.
//  Copyright © 2016 IBM. All rights reserved.
//

import Foundation

import CardKit
import CardKitRuntime
import DroneCardKit
import PromiseKit

public class DummyDJIDroneToken: ExecutableTokenCard { //, DroneToken {
    let delay: TimeInterval = 3.0
    
    public var homeLocation: DCKCoordinate2D?
    
    public var currentLocation: DCKCoordinate2D?
    public var currentAltitude: DCKRelativeAltitude?
    public var currentAttitude: DCKAttitude?
    
    public var areMotorsOn: Bool?
    public var isLandingGearDown: Bool?
    
    var methodCalls: [String] = []
    
    override public init(with card: TokenCard) {
        self.homeLocation = DCKCoordinate2D(latitude: 0, longitude: 0)
        self.currentLocation = DCKCoordinate2D(latitude: 0, longitude: 0)
        self.currentAltitude = DCKRelativeAltitude(metersAboveGroundAtTakeoff: 0)
        self.currentAttitude = DCKAttitude(yaw: DCKAngle(degrees: 0), pitch: DCKAngle(degrees: 0), roll: DCKAngle(degrees: 0))
        self.areMotorsOn = false
        self.isLandingGearDown = true
        
        super.init(with: card)
    }
    
    // MARK: Instance Methods
    // MARK: DroneToken
    public func turnMotorsOn(completionHandler: DroneTokenCompletionHandler) -> Void {
        areMotorsOn = true
        Thread.sleep(forTimeInterval: 3.0)
        completionHandler(nil)
    }
    
    /*
    
    public func turnMotorsOnPV() -> Promise<Void> {
        return Promise<Void>.empty(result: (), secondsToWait: delay).then {
            self.areMotorsOn = true
            return Promise<Void>.empty(result: ())
        }
    }
    
    public func turnMotorsOff() -> Promise<Void> {
        return Promise<Void>.empty(result: (), secondsToWait: delay).then {
            self.areMotorsOn = false
            return Promise<Void>.empty(result: ())
        }
    }
    
    public func takeOff(at altitude: DCKRelativeAltitude?) -> Promise<Void> {
        return Promise<Void>.empty(result: (), secondsToWait: delay).then {
            let _ = self.turnMotorsOnPV()
            let _ = self.landingGear(down: false)
            
            var newAltitude = DCKRelativeAltitude(metersAboveGroundAtTakeoff: 1)
            
            if let specifiedAltitude = altitude {
                newAltitude = specifiedAltitude
            }
            
            self.currentAltitude = newAltitude
            
            return Promise<Void>.empty(result: ())
        }
    }
    
    public func hover(at altitude: DCKRelativeAltitude?, withYaw yaw: DCKAngle?) -> Promise<Void> {
        return Promise<Void>.empty(result: (), secondsToWait: delay).then {
            if let specifiedAltitude = altitude {
                self.currentAltitude = specifiedAltitude
            }
            
            return Promise<Void>.empty(result: ())
        }
    }
    
    public func fly(to coordinate: DCKCoordinate2D, atYaw yaw: DCKAngle?, atAltitude altitude: DCKRelativeAltitude?, atSpeed speed: DCKSpeed?) -> Promise<Void> {
        
        return Promise<Void>.empty(result: (), secondsToWait: delay).then {
            let newYaw: DCKAngle
            if let yaw = yaw {
                newYaw = yaw
            } else {
                newYaw = self.currentAttitude!.yaw
            }
            
            let newCoord = DCKCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
            self.currentLocation = newCoord
            
            if let altitude = altitude {
                self.currentAltitude = altitude
            }
            
            let newAttitude = DCKAttitude(yaw: newYaw, pitch: self.currentAttitude!.pitch, roll: self.currentAttitude!.roll)
            self.currentAttitude = newAttitude
            
            return Promise<Void>.empty(result: ())
        }
        
     
    }
    
    public func fly(on path: DCKCoordinate2DPath, atAltitude altitude: DCKRelativeAltitude?, atSpeed speed: DCKSpeed?) -> Promise<Void> {
        return Promise<Void>.empty(result: (), secondsToWait: delay).then {
            var flightPromise: Promise<Void> = firstly {
                return Promise<Void>.empty(result: ())
            }
            
            for coord in path.path {
                flightPromise = flightPromise.then {
                    self.fly(to: coord, atAltitude: altitude, atSpeed: speed)
                }
            }
            
            return flightPromise
        }
    }
    
    public func fly(on path: DCKCoordinate3DPath, atSpeed speed: DCKSpeed?) -> Promise<Void> {
        return Promise<Void>.empty(result: (), secondsToWait: delay).then {
            var flightPromise: Promise<Void> = firstly {
                return Promise<Void>.empty(result: ())
            }
            
            for coord in path.path {
                flightPromise = flightPromise.then {
                    _ -> Promise<Void> in
                    self.fly(to: coord.as2D(), atAltitude: coord.altitude, atSpeed: speed)
                }
            }
            
            return flightPromise
        }
        

    }
    
    public func returnHome(atAltitude altitude: DCKRelativeAltitude?, atSpeed speed: DCKSpeed?) -> Promise<Void> {
        return Promise<Void>.empty(result: (), secondsToWait: delay).then {
            self.fly(to: self.homeLocation!)
        }
    }
    
    public func landingGear(down: Bool) -> Promise<Void> {
        return Promise<Void>.empty(result: (), secondsToWait: delay).then {
            self.isLandingGearDown = down
            
            return Promise<Void>.empty(result: ())
        }
    }
    
    public func land() -> Promise<Void> {
        return Promise<Void>.empty(result: (), secondsToWait: delay).then {
            let newAltitude = DCKRelativeAltitude(metersAboveGroundAtTakeoff: 0)
            self.currentAltitude = newAltitude
            
            return Promise<Void>.empty(result: ())
        }
    }
 
 */
}
