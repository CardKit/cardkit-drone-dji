//
//  DJIDroneToken.swift
//  DroneCardKit
//
//  Created by Justin Weisz on 9/23/16.
//  Copyright © 2016 IBM. All rights reserved.
//

import Foundation

import CardKit
import CardKitRuntime
import DroneCardKit

import DJISDK

// MARK: DJIDroneToken

public class DJIDroneToken: ExecutableToken, DroneToken {
    private let sleepTimeInSeconds = 1.0
    private let aircraft: DJIAircraft
    
    // swiftlint:disable:next weak_delegate
    private let flightControllerDelegate = FlightControllerDelegate()
    
    // MARK: Computed Properties
    
    public var homeLocation: DCKCoordinate2D? {
        guard let location: CLLocation = self.flightControllerDelegate.state?.homeLocation else { return nil }
        return DCKCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }
    
    public var currentLocation: DCKCoordinate2D? {
        guard let location: CLLocation = self.flightControllerDelegate.state?.aircraftLocation else { return nil }
        return DCKCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }
    
    public var currentAltitude: DCKRelativeAltitude? {
        guard let altitude: Double = self.flightControllerDelegate.state?.altitude else { return nil }
        return DCKRelativeAltitude(metersAboveGroundAtTakeoff: altitude)
    }
    
    public var currentAttitude: DCKAttitude? {
        guard let attitude: DJIAttitude = flightControllerDelegate.state?.attitude else { return nil }
        return DCKAttitude(yaw: DCKAngle(degrees: attitude.yaw), pitch: DCKAngle(degrees: attitude.pitch), roll: DCKAngle(degrees: attitude.roll))
    }
    
    public var areMotorsOn: Bool {
        return self.flightControllerDelegate.state?.areMotorsOn ?? false
    }
    
    public var isFlying: Bool {
        return self.flightControllerDelegate.state?.isFlying ?? false
    }
    
    public var isLandingGearDown: Bool {
        guard let landingGear: DJILandingGear = self.aircraft.flightController?.landingGear else { return false }
        return landingGear.state == .deployed
    }
    
    // MARK: Init
    
    public init(with card: TokenCard, for aircraft: DJIAircraft) {
        self.aircraft = aircraft
        self.aircraft.flightController?.delegate = self.flightControllerDelegate
        super.init(with: card)
    }
    
    // MARK: DroneToken
    
    public func spinMotors(on: Bool) throws {
        print("spin motors: \(on)")
        if on {
            try DispatchQueue.executeSynchronously { self.aircraft.flightController?.turnOnMotors(completion: $0) }
        } else {
            try DispatchQueue.executeSynchronously { self.aircraft.flightController?.turnOffMotors(completion: $0) }
        }
    }
    
    public func takeOff(at altitude: DCKRelativeAltitude?) throws {
        print("drone taking off and climbing to altitude \(String(describing: altitude))")
        
        var mission: [DJIMissionAction] = []
        
        let takeOff = DJITakeOffAction()
        mission.append(takeOff)
        
        if let altitude = altitude?.metersAboveGroundAtTakeoff {
            guard let climbToAltitude = DJIGoToAction(altitude: altitude) else {
                throw DJIDroneTokenError.failedToCreateMissionAction
            }
            
            mission.append(climbToAltitude)
        }
        
        try self.executeMission(mission)
    }
    
    public func hover(at altitude: DCKRelativeAltitude?) throws {
        print("drone hovering at altitude: \(String(describing: altitude))")
        
        var mission: [DJIMissionAction] = []
        
        if let altitude = altitude {
            guard let climbToAltitude = DJIGoToAction(altitude: altitude.metersAboveGroundAtTakeoff) else {
                throw DJIDroneTokenError.failedToCreateMissionAction
            }
            mission.append(climbToAltitude)
        }
        
        try self.executeMission(mission)
    }
    
    public func orient(to yaw: DCKAngle) throws {
        print("drone orienting to yaw: \(yaw)")
        
        var mission: [DJIMissionAction] = []
        
        guard let rotateToYaw = DJIAircraftYawAction(relativeAngle: yaw.degrees, andAngularVelocity: Defaults.angularVelocity) else {
            throw DJIDroneTokenError.failedToCreateMissionAction
        }
        
        mission.append(rotateToYaw)
        
        try self.executeMission(mission)
    }
    
    public func fly(to coordinate: DCKCoordinate2D, atAltitude altitude: DCKRelativeAltitude?, atSpeed speed: DCKSpeed?) throws {
        print("drone fly to coordinate: [\(coordinate)] atAltitude: \(String(describing: altitude)) atSpeed: \(String(describing: speed))")
        
        var mission: [DJIMissionAction] = []
        
        let location: CLLocationCoordinate2D = CLLocationCoordinate2DMake(coordinate.latitude, coordinate.longitude)
        
        var goToLocation: DJIGoToAction? = nil
        
        if let altitude = altitude {
            goToLocation = DJIGoToAction(coordinate: location, altitude: altitude.metersAboveGroundAtTakeoff)
        } else {
            goToLocation = DJIGoToAction(coordinate: location)
        }
        
        if let speed = speed {
            goToLocation?.flightSpeed = Float(speed.metersPerSecond)
        }
        
        if let goToLocation = goToLocation {
            mission.append(goToLocation)
        } else {
            throw DJIDroneTokenError.failedToCreateMissionAction
        }
        
        try self.executeMission(mission)
    }
    
    public func fly(on path: DCKCoordinate2DPath, atAltitude altitude: DCKRelativeAltitude?, atSpeed speed: DCKSpeed?) throws {
        print("drone fly on path: [\(path)] atAltitude: \(String(describing: altitude)) atSpeed: \(String(describing: speed))")
        
        var mission: [DJIMissionAction] = []
        
        for coordinate in path.path {
            let location: CLLocationCoordinate2D = CLLocationCoordinate2DMake(coordinate.latitude, coordinate.longitude)
            var goToLocation: DJIGoToAction? = nil
            
            if let altitude = altitude {
                goToLocation = DJIGoToAction(coordinate: location, altitude: altitude.metersAboveGroundAtTakeoff)
            } else {
                goToLocation = DJIGoToAction(coordinate: location)
            }
            
            if let speed = speed {
                goToLocation?.flightSpeed = Float(speed.metersPerSecond)
            }
            
            if let goToLocation = goToLocation {
                mission.append(goToLocation)
            } else {
                throw DJIDroneTokenError.failedToCreateMissionAction
            }
        }
        
        try self.executeMission(mission)
    }
    
    public func fly(on path: DCKCoordinate3DPath, atSpeed speed: DCKSpeed?) throws {
        print("drone flying on path: [\(path)] at current altitude at speed \(String(describing: speed))")
        
        var mission: [DJIMissionAction] = []
        
        for coordinate in path.path {
            let location: CLLocationCoordinate2D = CLLocationCoordinate2DMake(coordinate.latitude, coordinate.longitude)
            guard let goToLocation = DJIGoToAction(coordinate: location, altitude: coordinate.altitude.metersAboveGroundAtTakeoff) else {
                throw DJIDroneTokenError.failedToCreateMissionAction
            }
            
            if let speed = speed {
                goToLocation.flightSpeed = Float(speed.metersPerSecond)
            }
            
            mission.append(goToLocation)
        }
        
        try self.executeMission(mission)
    }
    
    public func circle(around center: DCKCoordinate2D, atRadius radius: DCKDistance, atAltitude altitude: DCKRelativeAltitude?, atAngularVelocity angularVelocity: DCKAngularVelocity?) throws {
        print("drone flying in circle around \(center) at radius \(radius) at altitude \(String(describing: altitude)) at angular velocity \(String(describing: angularVelocity))")
        
        let hotpointMission = DJIHotpointMission()
        
        // clamp the radius
        let radius = clamp(value: Float(radius.meters), min: DJIHotpointMinRadius, max: DJIHotpointMaxRadius)
        hotpointMission.radius = radius
        
        // clamp the altitude
        if let altitude = altitude {
            hotpointMission.altitude = clamp(value: Float(altitude.metersAboveGroundAtTakeoff), min: DJIHotpointMinAltitude, max: DJIHotpointMaxAltitude)
        }
        
        // round the angular velocity since DJI only supports whole numbers
        if let angularVelocity = angularVelocity {
            let degreesPerSecond = Int(angularVelocity.degreesPerSecond.rounded())
            hotpointMission.angularVelocity = Int(degreesPerSecond)
        }
        
        // point toward the center of the circle
        hotpointMission.heading = .towardHotpoint
        
        // make sure the hotpoint mission is valid, otherwise throw the error
        if let error = hotpointMission.checkParameters() {
            throw error
        }
        
        // it's go time
        guard let circle = DJIHotpointAction(mission: hotpointMission) else {
            throw DJIDroneTokenError.failedToCreateMissionAction
        }
        
        try self.executeMission([circle])
    }

    public func returnHome() throws {
        print ("drone returning home")
        
        let goHome = DJIGoHomeAction()
        try self.executeMission([goHome])
    }
    
    public func landingGear(down: Bool) throws {
        if down {
            try DispatchQueue.executeSynchronously { self.aircraft.flightController?.landingGear?.deploy(completion: $0) }
        } else {
            try DispatchQueue.executeSynchronously { self.aircraft.flightController?.landingGear?.retract(completion: $0) }
        }
    }
    
    public func land() throws {
        print("landing drone")
        
        // cancel any timeline missions in progress
        guard let missionControl = DJISDKManager.missionControl() else {
            throw DJIDroneTokenError.failedToObtainMissionControl
        }
        missionControl.stopTimeline()
        
        // tell the flight controller to start landing
        try DispatchQueue.executeSynchronously { self.aircraft.flightController?.startLanding(completion: $0) }
        
        // wait for drone to reach the height to ask for landing confirmation
        while let ready = self.flightControllerDelegate.state?.isLandingConfirmationNeeded, !ready {
            Thread.sleep(forTimeInterval: self.sleepTimeInSeconds)
        }
        
        // drone is hovering, confirm it is OK to land
        try DispatchQueue.executeSynchronously { self.aircraft.flightController?.confirmLanding(completion: $0) }
        
        // wait until landing is completely finished
        while let areMotorsOn = self.flightControllerDelegate.state?.areMotorsOn, areMotorsOn {
            Thread.sleep(forTimeInterval: self.sleepTimeInSeconds)
        }
        
        // turn the motors off
        try self.spinMotors(on: false)
    }
    
    // MARK: - Instance Methods
    
    private func executeMission(_ mission: [DJIMissionAction]) throws {
        guard let missionControl = DJISDKManager.missionControl() else {
            throw DJIDroneTokenError.failedToObtainMissionControl
        }
        
        // stop & reset any previous timeline
        missionControl.stopTimeline()
        
        // add the mission actions to the timeline
        missionControl.scheduleElements(mission)
        
        // listen for state changes
        var isExecuting = true
        var missionError: Error? = nil
        missionControl.addListener(self, toTimelineProgressWith: { (event: DJIMissionControlTimelineEvent, _, error: Error?, _) in
            switch event {
            case .started:
                isExecuting = true
            case .startError:
                isExecuting = false
            case .stopError:
                isExecuting = false
            case .stopped:
                isExecuting = false
            case .finished:
                isExecuting = false
            default:
                break
            }
            
            // capture any error that occurred
            missionError = error
        })
        
        // execute the mission
        missionControl.startTimeline()
        
        // wait for the mission to finish
        try DispatchQueue.executeSynchronously { asyncCompletionHandler in
            repeat {
                Thread.sleep(forTimeInterval: 1)
            } while isExecuting == false
            asyncCompletionHandler?(nil)
        }
        
        // throw any error that occurred
        if let error = missionError {
            throw error
        }
    }
    
    /// Clamp the given value to the range; values that fall below the range are held at the minimum,
    /// and values that fall above the range are held at the maximu.
    fileprivate func clamp(value: Float, min: Float, max: Float) -> Float {
        if value < min { return min }
        if value > max { return max }
        return value
    }
}

// MARK: - Defaults

// swiftlint:disable:next private_over_fileprivate
fileprivate struct Defaults {
    /// Default speed is 2.0 meters per second
    static let speed: Double = 2.0
    
    /// Default angular velocity is 20 degrees per second
    static let angularVelocity = 20.0
}


// MARK: - DJIDroneTokenError

public enum DJIDroneTokenError: Error {
    case failedToObtainMissionControl
    case failedToCreateMissionAction
    case indeterminateCurrentState
    case anotherMissionCurrentlyExecuting
    case failedToInstantiateVirtualStickMode
    case failedToPerformVirtualStickAction
}

// MARK: - FlightControllerDelegate

// DJIFlightControllerDelegates must inherit from NSObject. We can't make DJIDroneToken inherit from
// NSObject since it inherits from ExecutableToken (which isn't an NSObject), so we use a private
// class for this instead.
// swiftlint:disable:next private_over_fileprivate
fileprivate class FlightControllerDelegate: NSObject, DJIFlightControllerDelegate {
    var state: DJIFlightControllerState?
    var imuState: DJIIMUState?
    
    func flightController(_ fc: DJIFlightController, didUpdate state: DJIFlightControllerState) {
        self.state = state
    }
    
    func flightController(_ fc: DJIFlightController, didUpdate imuState: DJIIMUState) {
        self.imuState = imuState
    }
}
