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

public class DummyDroneToken: ExecutableTokenCard, DroneToken {
    let prefix = ">> "
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
    public func spinMotors(on: Bool, completionHandler: DroneTokenCompletionHandler?) {
        print("\(prefix) DummyDroneToken > turnMotorsOn()")
        Thread.sleep(forTimeInterval: delay)
        
        areMotorsOn = on
        completionHandler?(nil)
    }
    
    public func takeOff(at altitude: DCKRelativeAltitude?, completionHandler: DroneTokenCompletionHandler?) {
        print("\(prefix) DummyDroneToken > takeOff(at: \(altitude))")
        Thread.sleep(forTimeInterval: delay)
        
        spinMotors(on: true) { (error) in
            if let error = error {
                completionHandler?(error)
                return
            }
        }
        
        landingGear(down: false) { (error) in
            if let error = error {
                completionHandler?(error)
                return
            }
        }
        
        var newAltitude = DCKRelativeAltitude(metersAboveGroundAtTakeoff: 1)
        
        if let specifiedAltitude = altitude {
            newAltitude = specifiedAltitude
        }
        
        self.currentAltitude = newAltitude
        
        completionHandler?(nil)
    }
    
    public func hover(at altitude: DCKRelativeAltitude?, withYaw yaw: DCKAngle?, completionHandler: DroneTokenCompletionHandler?) {
        print("\(prefix) DummyDroneToken > hover(at: \(altitude), withYaw: \(yaw))")
        Thread.sleep(forTimeInterval: delay)
        
        if let specifiedAltitude = altitude {
            self.currentAltitude = specifiedAltitude
        }
        
        completionHandler?(nil)
    }
    
    public func fly(to coordinate: DCKCoordinate2D, atYaw yaw: DCKAngle?, atAltitude altitude: DCKRelativeAltitude?, atSpeed speed: DCKSpeed?, completionHandler: DroneTokenCompletionHandler?) {
        print("\(prefix) DummyDroneToken > fly(to: \(coordinate), atYaw: \(yaw), atAltitude: \(altitude), atSpeed: \(speed))")
        Thread.sleep(forTimeInterval: delay)
        
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
        
        completionHandler?(nil)
    }
    
    public func fly(on path: DCKCoordinate2DPath, atAltitude altitude: DCKRelativeAltitude?, atSpeed speed: DCKSpeed?, completionHandler: DroneTokenCompletionHandler?) {
        print("\(prefix) DummyDroneToken > fly(on: \(path), atAltitude: \(altitude), atSpeed: \(speed))")
        Thread.sleep(forTimeInterval: delay)
        
        var error: Error? = nil
        for coord in path.path {
            
            let semaphore = DispatchSemaphore(value: 0)
            
            self.fly(to: coord, atAltitude: altitude, atSpeed: speed) { e in
                error = e
                semaphore.signal()
            }
            
            semaphore.wait()
            
            if error != nil {
                break
            }
        }
        
        completionHandler?(error)
    }
    
    public func fly(on path: DCKCoordinate3DPath, atSpeed speed: DCKSpeed?, completionHandler: DroneTokenCompletionHandler?) {
        print("\(prefix) DummyDroneToken > fly(on: \(path), atSpeed: \(speed))")
        Thread.sleep(forTimeInterval: delay)
        
        var error: Error? = nil
        for coord in path.path {
            
            let semaphore = DispatchSemaphore(value: 0)
            
            self.fly(to: coord.as2D(), atAltitude: coord.altitude, atSpeed: speed) { e in
                error = e
                semaphore.signal()
            }
            
            semaphore.wait()
            
            if error != nil {
                break
            }
        }
        
        completionHandler?(error)
    }
    
    public func returnHome(atAltitude altitude: DCKRelativeAltitude?, atSpeed speed: DCKSpeed?, completionHandler: DroneTokenCompletionHandler?) {
        print("\(prefix) DummyDroneToken > returnHome(atAltitude: \(altitude), atSpeed: \(speed))")
        Thread.sleep(forTimeInterval: delay)
        
        self.fly(to: self.homeLocation!) { error in
            completionHandler?(error)
        }
    }
    
    public func landingGear(down: Bool, completionHandler: DroneTokenCompletionHandler?) {
        print("\(prefix) DummyDroneToken > landingGear(down: \(down))")
        Thread.sleep(forTimeInterval: delay)
        
        self.isLandingGearDown = down
    }
    
    public func land(completionHandler: DroneTokenCompletionHandler?) {
        print("\(prefix) DummyDroneToken > land()")
        Thread.sleep(forTimeInterval: delay)
        
        let newAltitude = DCKRelativeAltitude(metersAboveGroundAtTakeoff: 0)
        self.currentAltitude = newAltitude
        completionHandler?(nil)
    }
}
