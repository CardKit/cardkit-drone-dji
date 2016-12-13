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
    
    init(with card: TokenCard, for aircraft: DJIAircraft) {
        self.aircraft = aircraft
        self.aircraft.flightController?.delegate = self.flightControllerDelegate
        super.init(with: card)
        
    }
    
    //
    //    func areMotorsOn() -> Promise<Bool>
    //    func motors(spinning: Bool) -> Promise<Void>
    //
    //    func currentLocation() -> Promise<DCKCoordinate3D>
    //    func currentOrientation() -> Promise<DCKOrientation>
    //
    //    func hover(withYaw yaw: DCKAngle?) -> Promise<Void>
    //
    //    func fly(to altitude: DCKAltitude, withYaw yaw: DCKAngle?, atSpeed speed: DCKVelocity?) -> Promise<Void>
    //    func fly(to coordinate: DCKCoordinate2D, atAltitude altitude: DCKAltitude?, withYaw yaw: DCKAngle?, atSpeed speed: DCKVelocity?) -> Promise<Void>
    //    func fly(on path: DCKCoordinate2DPath, atSpeed speed: DCKVelocity?) -> Promise<Void>
    //    func fly(on path: DCKCoordinate3DPath, atSpeed speed: DCKVelocity?) -> Promise<Void>
    //
    //    func setHome(location: DCKCoordinate2D)
    //    func homeLocation() -> Promise<DCKCoordinate2D>
    //    func returnHome(withYaw yaw: DCKAngle?, atSpeed speed: DCKVelocity?) -> Promise<Void>
    //
    //    func landingGear(down: Bool) -> Promise<Void>
    //
    //    func land() -> Promise<Void>
    
    //MARK: DroneToken
    
    
    public func areMotorsOn() -> Promise<Bool> {
        return Promise {fulfill, reject in
            guard let motorsOn = flightControllerDelegate.currentState?.areMotorsOn else {
                reject(DroneTokenError.FailureRetrievingState)
            }
            
            fulfill(motorsOn)
        }
    }
    
    public func motors(spinning: Bool) -> Promise<Void> {
        if spinning {
            return PromiseKit.wrap{
                aircraft.flightController?.turnOnMotors(completion: $0)
            }
        }
        
        return PromiseKit.wrap{
            aircraft.flightController?.turnOffMotors(completion: $0)
        }
    }
    
    
    public func currentLocation() -> Promise<DCKCoordinate3D> {
        return Promise {fulfill, reject in
            guard let location = flightControllerDelegate.currentState?.aircraftLocation else {
                reject(DroneTokenError.FailureRetrievingState)
            }
            
            guard let altitude = flightControllerDelegate.currentState?.altitude else {
                reject(DroneTokenError.FailureRetrievingState)
            }
            
            let relativeAltObject = DCKRelativeAltitude(metersAboveGroundAtTakeoff: altitude)
            let currentLocObject = DCKCoordinate3D(latitude: location.latitude, longitude: location.longitude, altitude: relativeAltObject)
            
            fulfill(currentLocObject)
        }
    }
    
    public func currentOrientation() -> Promise<DCKOrientation> {
        return Promise {fulfill, reject in
            guard let attitude = flightControllerDelegate.currentState?.attitude else {
                reject(DroneTokenError.FailureRetrievingState)
            }
            
            let yaw = DCKAngle(degrees: attitude.yaw)
            let pitch = DCKAngle(degrees: attitude.pitch)
            let roll = DCKAngle(degrees: attitude.roll)
            let attitudeObj = DCKOrientation(yaw: yaw, pitch: pitch, roll: roll)
            
            fulfill(attitudeObj)
        }
    }
    
    public func hover(withYaw yaw: DCKAngle?) -> Promise<Void> {
        // TODO: cancel everything & hover
        
        if let desiredYaw = yaw?.degrees,
            let currentYaw = flightControllerDelegate.currentState?.attitude.yaw {
            let motionYaw = desiredYaw - currentYaw
            
            
            let flightControlData = DJIVirtualStickFlightControlData(pitch: 0, roll: 0, yaw: Float(motionYaw), verticalThrottle: 0)
            
            aircraft.flightController.
            
            return
                firstly {
                    PromiseKit.wrap { aircraft.flightController?.setControlMode(DJIVirtualStickYawControlMode.angle, withCompletion: $0) }
                    }.then { _ in
                        PromiseKit.wrap { aircraft.flightController?.enableVirtualStickControlMode(completion: $0) }
                    }.then { _ in
                        PromiseKit.wrap { aircraft.flightController?.send(controlData: flightControlData, withCompletion: $0) }
                    }.then  { _ in
                        PromiseKit.wrap { aircraft.flightController?.disableVirtualStickControlMode(completion: $0) }
            }
        }
        
        return Promise.empty()
    }
    
    
    // --------------
    
    
    public func takeOff() -> Promise<Void> {
        print("drone taking off!")
        return PromiseKit.wrap {
            aircraft.flightController?.takeoff(completion: $0)
        }
    }
    
    public func takeOff(climbingTo altitude: Double) -> Promise<Void> {
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
        waypoint.altitude = Float(altitude)
        
        // add it to the mission
        mission.add(waypoint)
        
        // execute it
        return self.executeWaypointMission(mission: mission)
    }
    
    public func fly(to coordinate: DCKCoordinate2D, atSpeed speed: Double = Defaults.speed) -> Promise<Void> {
        let path = DCKCoordinate2DPath(path: [coordinate])
        return self.fly(on: path, atSpeed: speed)
    }
    
    public func fly(to coordinate: DCKCoordinate3D, atSpeed speed: Double = Defaults.speed) -> Promise<Void> {
        let path = DCKCoordinate3DPath(path: [coordinate])
        return self.fly(on: path, atSpeed: speed)
    }
    
    public func fly(on path: DCKCoordinate2DPath, atSpeed speed: Double = Defaults.speed) -> Promise<Void> {
        print("drone flying on path: [\(path)] at current altitude at speed \(speed)")
        
        let mission = DJIWaypointMission()
        mission.finishedAction = .noAction
        mission.headingMode = .auto
        mission.flightPathMode = .normal
        
        if speed > 0 {
            mission.autoFlightSpeed = Float(speed)
        }
        
        for coordinate in path.path {
            // create a waypoint to each destination
            let c = CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let waypoint = DJIWaypoint(coordinate: c)
            
            // add it to the mission
            mission.add(waypoint)
        }
        
        // execute it
        return self.executeWaypointMission(mission: mission)
    }
    
    public func fly(on path: DCKCoordinate3DPath, atSpeed speed: Double = Defaults.speed) -> Promise<Void> {
        print("drone flying on path: [\(path)] at speed \(speed)")
        
        let mission = DJIWaypointMission()
        mission.finishedAction = .noAction
        mission.headingMode = .auto
        mission.flightPathMode = .normal
        
        if speed > 0 {
            mission.autoFlightSpeed = Float(speed)
        }
        
        for coordinate in path.path {
            // create a waypoint to each destination
            let c = CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let waypoint = DJIWaypoint(coordinate: c)
            waypoint.altitude = Float(coordinate.altitude.metersAboveSeaLevel)
            
            // add it to the mission
            mission.add(waypoint)
        }
        
        // execute it
        return self.executeWaypointMission(mission: mission)
    }
    
    public func returnHome() -> Promise<Void> {
        print("drone returning home!")
        
        let goHome = DJIGoHomeStep()
        return self.execute(missionSteps: [goHome])
    }
    
    public func land() -> Promise<Void> {
        print("drone landing!")
        
        return PromiseKit.wrap {
            aircraft.flightController?.autoLanding(completion: $0)
        }
    }
    
    //MARK: Instance Methods
    
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
    
    
    public func location() -> DCKCoordinate2D {
        fatalError("Not Implemented")
    }
    
    public func landingGear(down: Bool) -> Promise<Void> {
        fatalError("Not Implemented")
    }
    
    public func getHome() -> DCKCoordinate2D {
        fatalError("Not Implemented")
    }
    
    public func setHome(location: DCKCoordinate2D) {
        fatalError("Not Implemented")
    }
    
    public func takeOffCancel() -> Promise<Void> {
        fatalError("Not Implemented")
    }
    
    public func returnHomeCancel() -> Promise<Void> {
        fatalError("Not Implemented")
    }
    
    public func landCancel() -> Promise<Void> {
        fatalError("Not Implemented")
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
