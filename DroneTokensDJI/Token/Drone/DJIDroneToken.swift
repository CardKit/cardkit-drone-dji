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

//MARK: DJIDroneToken
public class DJIDroneToken: ExecutableTokenCard, DroneToken {
    
    
    private let aircraft: DJIAircraft
    private let flightControllerDelegate: FlightControllerDelegate = FlightControllerDelegate()
    
    // MARK: Computed Properties
    
    public var homeLocation: DCKCoordinate2D? {
        guard let coordinates = self.flightControllerDelegate.currentState?.homeLocation else {
            return nil
        }
        
        return DCKCoordinate2D(latitude: coordinates.latitude, longitude: coordinates.longitude)
    }
    
    public var currentLocation: DCKCoordinate2D? {
        guard let location = flightControllerDelegate.currentState?.aircraftLocation else {
            return nil
        }
        
        return DCKCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    }
    
    public var currentAltitude: DCKRelativeAltitude? {
        guard let altitude = flightControllerDelegate.currentState?.altitude else {
            return nil
        }
        
        return DCKRelativeAltitude(metersAboveGroundAtTakeoff: Double(altitude))
    }
    
    public var currentAttitude: DCKAttitude? {
        guard let attitude = flightControllerDelegate.currentState?.attitude else {
            return nil
        }
        
        return DCKAttitude(yaw: DCKAngle(degrees: attitude.yaw), pitch: DCKAngle(degrees: attitude.pitch), roll: DCKAngle(degrees: attitude.roll))
    }
    
    public var areMotorsOn: Bool? {
        return flightControllerDelegate.currentState?.areMotorsOn
    }
    
    public var isLandingGearDown: Bool? {
        guard let landingGear = self.aircraft.flightController?.landingGear else {
            return false;
        }
        
        return landingGear.status == .deployed
    }
    
    // MARK: init
    
    public init(with card: TokenCard, for aircraft: DJIAircraft) {
        self.aircraft = aircraft
        self.aircraft.flightController?.delegate = self.flightControllerDelegate
        super.init(with: card)
        
    }
    
    // MARK: Instance Methods
    // MARK: DroneToken
    public func turnMotorsOn(completionHandler: DroneTokenCompletionHandler?) {
        aircraft.flightController?.turnOnMotors(completion: completionHandler)
    }
    
    public func turnMotorsOff(completionHandler: DroneTokenCompletionHandler?) {
        aircraft.flightController?.turnOffMotors(completion: completionHandler)
    }
    
    public func takeOff(at altitude: DCKRelativeAltitude?, completionHandler: DroneTokenCompletionHandler?) {
        if let desiredAltitude = altitude {
            print("drone taking off and climbing to altitude \(altitude)")
            
            guard let state = self.flightControllerDelegate.currentState else {
                completionHandler?(DJIDroneTokenError.indeterminateCurrentState)
                return
            }
            
            let mission = DJIWaypointMission()
            mission.finishedAction = .noAction
            mission.headingMode = .auto
            mission.flightPathMode = .normal
            
            // create a waypoint to the current coordinate
            let waypoint = DJIWaypoint(coordinate: state.aircraftLocation)
            
            // with the requested altitude
            waypoint.altitude = Float(desiredAltitude.metersAboveGroundAtTakeoff)
            
            // add it to the mission
            mission.add(waypoint)
            
            // execute it
            executeWaypointMission(mission: mission, completionHandler: completionHandler)
        } else {
            aircraft.flightController?.takeoff(completion: completionHandler)
        }
    }
    
    public func hover(at altitude: DCKRelativeAltitude?, withYaw yaw: DCKAngle?, completionHandler: DroneTokenCompletionHandler?) {
        // TODO: cancel everything & hover
        
        if let desiredYaw = yaw?.degrees,
            let currentYaw = flightControllerDelegate.currentState?.attitude.yaw {
            let motionYaw = desiredYaw - currentYaw
            
            
            let flightControlData = DJIVirtualStickFlightControlData(pitch: 0, roll: 0, yaw: Float(motionYaw), verticalThrottle: 0)
            
            DispatchQueue.global(qos: .default).async {
                let semaphore = DispatchSemaphore(value: 0)
                var error: Error? = nil
                
                if error != nil {
                    self.aircraft.flightController?.setControlMode(DJIFlightControllerControlMode.smart) { djiError in
                        error = djiError
                        semaphore.signal()
                    }
                    
                    semaphore.wait()
                }
                
                if error != nil {
                    self.aircraft.flightController?.enableVirtualStickControlMode() { djiError in
                        error = djiError
                        semaphore.signal()
                    }
                    
                    semaphore.wait()
                }
                
                if error != nil {
                    self.aircraft.flightController?.send(flightControlData) { djiError in
                        error = djiError
                        semaphore.signal()
                    }
                    
                    semaphore.wait()
                }
                
 
                if error != nil {
                    self.aircraft.flightController?.disableVirtualStickControlMode() { djiError in
                        error = djiError
                        semaphore.signal()
                    }
                    
                    semaphore.wait()
                }
            
                completionHandler?(error)
            }
        }
        else {
            aircraft.flightController?.setControlMode(DJIFlightControllerControlMode.smart) { djiError in
                completionHandler?(djiError)
            }
        }
    }
    
    public func fly(to coordinate: DCKCoordinate2D, atYaw yaw: DCKAngle?, atAltitude altitude: DCKRelativeAltitude?, atSpeed speed: DCKSpeed?, completionHandler: DroneTokenCompletionHandler?) {
        DispatchQueue.global(qos: .default).async {
            let semaphore = DispatchSemaphore(value: 0)
            var error: Error? = nil
            
            if error != nil && yaw != nil {
                self.hover(withYaw: yaw) { djiError in
                    error = djiError
                    semaphore.signal()
                }
                
                semaphore.wait()
            }
            
            if error != nil {
                self.fly(on: DCKCoordinate2DPath(path: [coordinate]), atAltitude: altitude, atSpeed: speed) { djiError in
                    error = djiError
                    semaphore.signal()
                }
                
                semaphore.wait()
            }
            
            completionHandler?(error)
        }
    }
    
    public func fly(on path: DCKCoordinate2DPath, atAltitude altitude: DCKRelativeAltitude?, atSpeed speed: DCKSpeed?, completionHandler: DroneTokenCompletionHandler?) {
        var altitudeInMeters: Double? = nil
        
        // if altitude was not passed, use current altitude
        if let userSetAltitude = altitude {
            altitudeInMeters = userSetAltitude.metersAboveGroundAtTakeoff
        } else if let currentAltitude = self.flightControllerDelegate.currentState?.altitude {
            altitudeInMeters = Double(currentAltitude)
        } else {
            completionHandler?(DroneTokenError.FailureRetrievingDroneState)
            return
        }
        
        let coordinate3DPath = path.path.map { (coordinate2d) -> DCKCoordinate3D in
            DCKCoordinate3D(latitude: coordinate2d.latitude, longitude: coordinate2d.longitude, altitude: DCKRelativeAltitude(metersAboveGroundAtTakeoff: altitudeInMeters!))
        }
        
        fly(on: DCKCoordinate3DPath(path: coordinate3DPath), atSpeed: speed, completionHandler: completionHandler)
    }
    
    public func fly(on path: DCKCoordinate3DPath, atSpeed speed: DCKSpeed?, completionHandler: DroneTokenCompletionHandler?) {
        print("drone flying on path: [\(path)] at current altitude at speed \(speed)")
        
        let mission = DJIWaypointMission()
        mission.finishedAction = .noAction
        mission.headingMode = .auto
        mission.flightPathMode = .normal
        
        if let speedInMetersPerSecond = speed?.metersPerSecond, speedInMetersPerSecond > 0 {
            mission.autoFlightSpeed = Float(speedInMetersPerSecond)
        }
        
        for coordinate in path.path {
            // create a waypoint to each destination
            let c = CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let waypoint = DJIWaypoint(coordinate: c)
            waypoint.altitude = Float(coordinate.altitude.metersAboveGroundAtTakeoff)
            
            // add it to the mission
            mission.add(waypoint)
        }
        
        // execute it
        executeWaypointMission(mission: mission, completionHandler: completionHandler)
    }
    
    public func returnHome(atAltitude altitude: DCKRelativeAltitude?, atSpeed speed: DCKSpeed?, completionHandler: DroneTokenCompletionHandler?) {
        guard let homeCoordinates = self.homeLocation else {
            completionHandler?(DroneTokenError.FailureRetrievingDroneState)
            return
        }
        
        fly(to: homeCoordinates, atAltitude: altitude, atSpeed: speed, completionHandler: completionHandler)

    }
    
    public func landingGear(down: Bool, completionHandler: DroneTokenCompletionHandler?) {
        if(down) {
            aircraft.flightController?.landingGear?.deployLandingGear(completion: completionHandler)
        }
        else {
            aircraft.flightController?.landingGear?.retractLandingGear(completion: completionHandler)
        }
    }
    
    public func land(completionHandler: DroneTokenCompletionHandler?) {
        self.aircraft.flightController?.autoLanding(completion: completionHandler)
    }
 
    // MARK: - Instance Methods
    
    private func executeWaypointMission(mission: DJIWaypointMission, completionHandler: DroneTokenCompletionHandler?) {
        // create a waypoint step
        guard let step = DJIWaypointStep(waypointMission: mission) else {
            completionHandler?(DJIDroneTokenError.failedToInstantiateWaypointStep)
            return
        }
        
        // execute it
        return execute(missionSteps: [step], completionHandler: completionHandler)
    }
    
    private func execute(missionSteps: [DJIMissionStep], completionHandler: DroneTokenCompletionHandler?) {
        DispatchQueue.global(qos: .default).async {
            let error = self.executeSync(missionSteps: missionSteps)
            completionHandler?(error)
        }
    }
    
    private func executeSync(missionSteps: [DJIMissionStep]) -> Error? {
        guard let mission = DJICustomMission(steps: missionSteps) else {
            return DJIDroneTokenError.failedToInstantiateCustomMission
        }
        
        guard let missionManager = DJIMissionManager.sharedInstance() else {
            return DJIDroneTokenError.failedToInstantiateMissionManager
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        
        missionManager.prepare(mission, withProgress: nil) { _ in
            semaphore.signal()
        }
        
        semaphore.wait()
        
        missionManager.startMissionExecution() { _ in
            semaphore.signal()
        }
        
        semaphore.wait()
        
        return nil
    }
 

}

//MARK:- DJIDroneTokenDefaults

fileprivate struct Defaults {
    static let speed: Double = 2.0
}


//MARK:- DJIDroneTokenError

public enum DJIDroneTokenError: Error {
    case failedToInstantiateCustomMission
    case failedToInstantiateMissionManager
    case failedToInstantiateWaypointStep
    case indeterminateCurrentState
}

//MARK:- FlightControllerDelegate

// DJIFlightControllerDelegates must inherit from NSObject. We can't make DJIDroneToken inherit from
// NSObject since it inherits from ExecutableTokenCard (which isn't an NSObject), so we use a private
// class for this instead.
fileprivate class FlightControllerDelegate: NSObject, DJIFlightControllerDelegate {
    var currentState: DJIFlightControllerCurrentState?
    
    func flightController(_ flightController: DJIFlightController, didUpdateSystemState state: DJIFlightControllerCurrentState) {
        self.currentState = state
    }
}
