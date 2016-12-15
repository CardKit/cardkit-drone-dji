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
import PromiseKit

//MARK: DJIDroneToken
public class DJIDroneToken: ExecutableTokenCard, DroneToken {
    
    private let aircraft: DJIAircraft
    private let flightControllerDelegate: FlightControllerDelegate = FlightControllerDelegate()
    
    public init(with card: TokenCard, for aircraft: DJIAircraft) {
        self.aircraft = aircraft
        self.aircraft.flightController?.delegate = self.flightControllerDelegate
        super.init(with: card)
        
    }
    
    //MARK: - DroneToken Protocol Implementation
    
    // MARK: Computed Properties
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
    
    
    public func turnMotorsOn() -> Promise<Void> {
        return PromiseKit.wrap {
            return aircraft.flightController?.turnOnMotors(completion: $0)
        }
    }
    
    public func turnMotorsOff() -> Promise<Void> {
        return PromiseKit.wrap{
            aircraft.flightController?.turnOffMotors(completion: $0)
        }
    }
    
    public var homeLocation: DCKCoordinate2D? {
        guard let coordinates = self.flightControllerDelegate.currentState?.homeLocation else {
            return nil
        }
        
        return DCKCoordinate2D(latitude: coordinates.latitude, longitude: coordinates.longitude)
    }
    
    public var isLandingGearDown: Bool? {
        guard let landingGear = self.aircraft.flightController?.landingGear else {
            return false;
        }
        
        return landingGear.status == .deployed
    }
    
    // MARK: Take Off
    
    public func takeOff(at altitude: DCKRelativeAltitude?) -> Promise<Void> {
        if let desiredAltitude = altitude {
            print("drone taking off and climbing to altitude \(altitude)")
            
            guard let state = self.flightControllerDelegate.currentState else {
                return Promise(error: DJIDroneTokenError.indeterminateCurrentState)
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
            return self.executeWaypointMission(mission: mission)
        } else {
            return PromiseKit.wrap{
                aircraft.flightController?.takeoff(completion: $0)
            }
        }
    }
    
    // MARK: Hover
    public func hover(at altitude: DCKRelativeAltitude?, withYaw yaw: DCKAngle?) -> Promise<Void> {
        // TODO: cancel everything & hover
        
        if let desiredYaw = yaw?.degrees,
            let currentYaw = flightControllerDelegate.currentState?.attitude.yaw {
            let motionYaw = desiredYaw - currentYaw
            
            
            let flightControlData = DJIVirtualStickFlightControlData(pitch: 0, roll: 0, yaw: Float(motionYaw), verticalThrottle: 0)
            
            return
                firstly { () -> Promise<Void> in
                    PromiseKit.wrap { aircraft.flightController?.setControlMode(DJIFlightControllerControlMode.smart, withCompletion: $0) }
                    }.then { () -> Promise<Void> in
                        PromiseKit.wrap { self.aircraft.flightController?.enableVirtualStickControlMode(completion: $0) }
                    }.then { () -> Promise<Void> in
                        PromiseKit.wrap { self.aircraft.flightController?.send(flightControlData, withCompletion: $0) }
                    }.then  { () -> Promise<Void> in
                        PromiseKit.wrap { self.aircraft.flightController?.disableVirtualStickControlMode(completion: $0) }
            }
        }
        
        return
            firstly { () -> Promise<Void> in
                PromiseKit.wrap { aircraft.flightController?.setControlMode(DJIFlightControllerControlMode.smart, withCompletion: $0) }
        }
    }
    
    // MARK: Fly To
    
    public func fly(to coordinate: DCKCoordinate2D, atYaw yaw: DCKAngle?, atAltitude altitude: DCKRelativeAltitude?, atSpeed speed: DCKSpeed?) -> Promise<Void> {
        return
            firstly {
                hover(withYaw: yaw)
                }.then { _ in
                    self.fly(on: DCKCoordinate2DPath(path: [coordinate]), atAltitude: altitude, atSpeed: speed)
        }
    }
    
    public func fly(on path: DCKCoordinate2DPath, atAltitude altitude: DCKRelativeAltitude?, atSpeed speed: DCKSpeed?) -> Promise<Void> {
        var altitudeInMeters: Double? = nil
        
        // if altitude was not passed, use current altitude
        if let userSetAltitude = altitude {
            altitudeInMeters = userSetAltitude.metersAboveGroundAtTakeoff
        } else if let currentAltitude = self.flightControllerDelegate.currentState?.altitude {
            altitudeInMeters = Double(currentAltitude)
        } else {
            return firstly {
                throw DroneTokenError.FailureRetrievingDroneState
            }
        }
        
        let coordinate3DPath = path.path.map { (coordinate2d) -> DCKCoordinate3D in
            DCKCoordinate3D(latitude: coordinate2d.latitude, longitude: coordinate2d.longitude, altitude: DCKRelativeAltitude(metersAboveGroundAtTakeoff: altitudeInMeters!))
        }
        
        return self.fly(on: DCKCoordinate3DPath(path: coordinate3DPath), atSpeed: speed)
    }
    
    public func fly(on path: DCKCoordinate3DPath, atSpeed speed: DCKSpeed?) -> Promise<Void> {
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
        return self.executeWaypointMission(mission: mission)
    }
    
    // MARK: Land/Return Home
    
    public func landingGear(down: Bool) -> Promise<Void> {
        if(down) {
            return PromiseKit.wrap {
                self.aircraft.flightController?.landingGear?.deployLandingGear(completion: $0)
            }
        }
        
        return PromiseKit.wrap {
            self.aircraft.flightController?.landingGear?.retractLandingGear(completion: $0)
        }
    }
    
    public func land() -> Promise<Void> {
        return PromiseKit.wrap {
            self.aircraft.flightController?.autoLanding(completion: $0)
        }
    }
    
    public func returnHome(atAltitude altitude: DCKRelativeAltitude?, atSpeed speed: DCKSpeed?) -> Promise<Void> {
        guard let homeCoordinates = self.homeLocation else {
            return firstly {
                throw DroneTokenError.FailureRetrievingDroneState
            }
        }
        
        return self.fly(to: homeCoordinates, atAltitude: altitude, atSpeed: speed)
    }
    
    // MARK: - Instance Methods
    
    private func executeWaypointMission(mission: DJIWaypointMission) -> Promise<Void> {
        // create a waypoint step
        guard let step = DJIWaypointStep(waypointMission: mission) else {
            return Promise(error: DJIDroneTokenError.failedToInstantiateWaypointStep)
        }
        
        // execute it
        return self.execute(missionSteps: [step])
    }
    
    private func execute(missionSteps: [DJIMissionStep]) -> Promise<Void> {
        guard let mission = DJICustomMission(steps: missionSteps) else {
            return Promise(error: DJIDroneTokenError.failedToInstantiateCustomMission)
        }
        
        guard let missionManager = DJIMissionManager.sharedInstance() else {
            return Promise(error: DJIDroneTokenError.failedToInstantiateMissionManager)
        }
        
        return PromiseKit.wrap {
            missionManager.prepare(mission, withProgress: nil, withCompletion: $0)
            }.then {
                PromiseKit.wrap { missionManager.startMissionExecution(completion: $0) }
        }
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
