//
//  DJIDroneToken.swift
//  DroneCardKit
//
//  Created by Justin Weisz on 9/23/16.
//  Copyright © 2016 IBM. All rights reserved.
//

// swiftlint:disable variable_name
// swiftlint:disable weak_delegate

import Foundation

import CardKit
import CardKitRuntime
import DroneCardKit

import DJISDK

// swiftlint complains that the FlightControllerDelegate and MissionManagerDelegate should be weak to avoid reference cycles
// However, I feel that this is not necessary with the way we are handing delegates in this class..

// We need to hold a strong reference to [MissionManagerDelegate] as [DJIMissionManager] is most likely holding a weak reference to [MissionManagerDelegate].
// [MissionManagerDelegate] stays in memory until [DJIDroneToken] gets deallocated. If we held a weak reference to [MissionManagerDelegate], then
// there is nothing stopping ARC from deallocating [MissionManagerDelegate].
//
//  Example: (single line indicates weak reference, double line indicates strong reference)
//
//    [MissionManagerDelegate]  <------  [DJIMissionManager]
//                    /\                    /\
//                    \\                   //
//                     \\                 //
//                      \\               //
//                        [DJIDroneToken]


// MARK: DJIDroneToken
public class DJIDroneToken: ExecutableTokenCard, DroneToken {
    private let sleepTimeInSeconds = 2.0 //in seconds
    private let aircraft: DJIAircraft
    private let flightControllerDelegate = FlightControllerDelegate()
    private let missionManagerDelegate = MissionManagerDelegate()
    private let missionManager = DJIMissionManager.sharedInstance()
    
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
        
        // jw: I think I disagree with normalizing this here, I thought the normalization
        // discussion we had was about the gimbal because different gimbals have different
        // ranges of motion.
        let normalizedAttitude = attitude.normalized()
        return DCKAttitude(yaw: DCKAngle(degrees: normalizedAttitude.yaw), pitch: DCKAngle(degrees: normalizedAttitude.pitch), roll: DCKAngle(degrees: normalizedAttitude.roll))
    }
    
    public var areMotorsOn: Bool? {
        return flightControllerDelegate.currentState?.areMotorsOn
    }
    
    public var isLandingGearDown: Bool? {
        guard let landingGear = self.aircraft.flightController?.landingGear else {
            return false
        }
        
        return landingGear.status == .deployed
    }
    
    // MARK: Init
    
    public init(with card: TokenCard, for aircraft: DJIAircraft) {
        self.aircraft = aircraft
        self.aircraft.flightController?.delegate = self.flightControllerDelegate
        missionManager?.delegate = missionManagerDelegate
        super.init(with: card)
    }
    
    // MARK: DroneToken
    
    public func spinMotors(on: Bool, completionHandler: AsyncExecutionCompletionHandler?) {
        if on {
            aircraft.flightController?.turnOnMotors(completion: completionHandler)
        } else {
            aircraft.flightController?.turnOffMotors(completion: completionHandler)
        }
    }
    
    public func takeOff(at altitude: DCKRelativeAltitude?, completionHandler: AsyncExecutionCompletionHandler?) {
        print("drone taking off and climbing to altitude \(altitude)")
        
        var missionSteps: [DJIMissionStep] = []
        
        let takeOffStep = DJITakeoffStep()
        missionSteps.append(takeOffStep)
        
        if let desiredAltitude = altitude?.metersAboveGroundAtTakeoff {
            
            guard let altitudeStep = DJIGoToStep(altitude: Float(desiredAltitude)) else {
                completionHandler?(DJIDroneTokenError.failedToInstantiateCustomMission)
                return
            }
            
            missionSteps.append(altitudeStep)
        }
        
        executeMission(missionSteps: missionSteps) { (djiError) in
            completionHandler?(djiError)
        }
    }
    
    public func hover(at altitude: DCKRelativeAltitude?, withYaw yaw: DCKAngle?, completionHandler: AsyncExecutionCompletionHandler?) {
        DispatchQueue.global(qos: .default).async {
            let semaphore = DispatchSemaphore(value: 0)
            var error: Error?
            
            // stop all current missions
            // we have to check if we are currently executing a mission before we stop it, or this occurs:
            
            // (Error Domain=DJISDKMissionErrorDomain Code=-5016 "Aircraft is not running a mission or current
            // mission object in mission manager is empty.(code:-5016)" UserInfo={NSLocalizedDescription=Aircraft
            // is not running a mission or current mission object in mission manager is empty.(code:-5016)})
            
            if error == nil && self.missionManager?.currentExecutingMission() != nil {
                self.missionManager?.stopMissionExecution { (djiError) in
                    semaphore.signal()
                    error = djiError
                }
                
                semaphore.wait()
            }
            
            // take off (incase if the drone is on the ground) and change altitude
            if error == nil {
                self.takeOff(at: altitude) { (djiError) in
                    error = djiError
                    semaphore.signal()
                }
                
                semaphore.wait()
            }
            
            // change yaw (if specified)
            // TODO: this method of controlling yaw does not work
            // it "freezes" the drone and does not allow for other commands to be sent (e.g. land)
//            if error == nil { //, let yawAngleInDegrees = yaw?.degrees {
//                let yawAngleInDegrees = 90
//                var ctrlData: DJIVirtualStickFlightControlData = DJIVirtualStickFlightControlData()
//                ctrlData.yaw = Float(yawAngleInDegrees)
//                
//                if let isVirtualStickAvailable = self.aircraft.flightController?.isVirtualStickControlModeAvailable(),
//                    isVirtualStickAvailable == true {
//                    self.aircraft.flightController?.send(ctrlData) { (djiError) in
//                        error = djiError
//                        semaphore.signal()
//                    }
//                }
//                
//                semaphore.wait()
//            }
            
            completionHandler?(error)
        }
    }
    
    public func fly(to coordinate: DCKCoordinate2D, atYaw yaw: DCKAngle?, atAltitude altitude: DCKRelativeAltitude?, atSpeed speed: DCKSpeed?, completionHandler: AsyncExecutionCompletionHandler?) {
        DispatchQueue.global(qos: .default).async {
            let semaphore = DispatchSemaphore(value: 0)
            var error: Error? = nil
            
            // change yaw
            if error == nil && yaw != nil {
                self.hover(withYaw: yaw) { djiError in
                    error = djiError
                    semaphore.signal()
                }
                
                semaphore.wait()
            }
            
            // fly to location
            if error == nil {
                let coord: CLLocationCoordinate2D = CLLocationCoordinate2DMake(coordinate.latitude, coordinate.longitude)
                
                var missionSteps: [DJIMissionStep] = []
                
                if let altitudeInMeters = altitude?.metersAboveGroundAtTakeoff,
                    let altitudeStep = DJIGoToStep(altitude: Float(altitudeInMeters)) {
                    missionSteps.append(altitudeStep)
                }
                
                if let flyStep = DJIGoToStep(coordinate: coord) {
                    if let speedInMetersPerSecond = speed?.metersPerSecond, speedInMetersPerSecond > 0 {
                        flyStep.flightSpeed = Float(speedInMetersPerSecond)
                    }
                    
                    missionSteps.append(flyStep)
                } else {
                    error = DJIDroneTokenError.failedToInstantiateCustomMission
                    semaphore.signal()
                }
                
                self.executeMission(missionSteps: missionSteps) { (djiError) in
                    error = djiError
                    semaphore.signal()
                }
                
                semaphore.wait()
            }
            
            completionHandler?(error)
        }
    }
    
    public func fly(on path: DCKCoordinate2DPath, atAltitude altitude: DCKRelativeAltitude?, atSpeed speed: DCKSpeed?, completionHandler: AsyncExecutionCompletionHandler?) {
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
    
    
    public func fly(on path: DCKCoordinate3DPath, atSpeed speed: DCKSpeed?, completionHandler: AsyncExecutionCompletionHandler?) {
        print("drone flying on path: [\(path)] at current altitude at speed \(speed)")
        
        let mission = DJIWaypointMission()
        mission.finishedAction = .noAction
        mission.headingMode = .auto
        mission.flightPathMode = .normal
        
        if let speedInMetersPerSecond = speed?.metersPerSecond, speedInMetersPerSecond > 0 {
            mission.autoFlightSpeed = Float(speedInMetersPerSecond)
        }
        
        if let latitude = self.currentLocation?.latitude, let longitude =  self.currentLocation?.longitude {
            let homeCoordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            mission.add(DJIWaypoint(coordinate: homeCoordinate))
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
    
    public func returnHome(atAltitude altitude: DCKRelativeAltitude?, atSpeed speed: DCKSpeed?, completionHandler: AsyncExecutionCompletionHandler?) {
        guard let homeCoordinates = self.homeLocation else {
            completionHandler?(DroneTokenError.FailureRetrievingDroneState)
            return
        }
        
        fly(to: homeCoordinates, atAltitude: altitude, atSpeed: speed, completionHandler: completionHandler)

    }
    
    public func landingGear(down: Bool, completionHandler: AsyncExecutionCompletionHandler?) {
        if down {
            aircraft.flightController?.landingGear?.deployLandingGear(completion: completionHandler)
        } else {
            aircraft.flightController?.landingGear?.retractLandingGear(completion: completionHandler)
        }
    }
    
    
    public func land(completionHandler: AsyncExecutionCompletionHandler?) {
        DispatchQueue.global(qos: .default).async {
            var error: Error?
            let semaphore = DispatchSemaphore(value: 0)
            
            /*
             Before we auto land, we need to stop any current missions. If this fails, we should
             still try to autoland. Maybe autoland will force the missions to stop executing.
             Therefore, since we are going to autoland anyways, we are ignoring the error in
             stopMissionExecution().
             */
            
            if error == nil {
                self.missionManager?.stopMissionExecution { _ in
                    semaphore.signal()
                }
                
                semaphore.wait()
            }
            
            if error == nil {
                self.aircraft.flightController?.autoLanding(completion: { (djiError) in
                    error = djiError
                    semaphore.signal()
                })
                semaphore.wait()
            }
            
            if error == nil {
                while let isFlying = self.flightControllerDelegate.currentState?.isFlying, isFlying {
                    Thread.sleep(forTimeInterval: self.sleepTimeInSeconds)
                }
            }
            
            completionHandler?(error)
        }
    }
 
    // MARK: - Instance Methods
    private func executeWaypointMission(mission: DJIWaypointMission, completionHandler: AsyncExecutionCompletionHandler?) {
        // create a waypoint step
        guard let step = DJIWaypointStep(waypointMission: mission) else {
            completionHandler?(DJIDroneTokenError.failedToInstantiateWaypointStep)
            return
        }
        
        // execute it
        return executeMission(missionSteps: [step], completionHandler: completionHandler)
    }
    
    private func executeMission(missionSteps: [DJIMissionStep], completionHandler: AsyncExecutionCompletionHandler?) {
        DispatchQueue.global(qos: .default).async {
            let error = self.executeMissionSync(missionSteps: missionSteps)
            completionHandler?(error)
        }
    }
    
    private func executeMissionSync(missionSteps: [DJIMissionStep]) -> Error? {
        guard let mission = DJICustomMission(steps: missionSteps) else {
            return DJIDroneTokenError.failedToInstantiateCustomMission
        }
        
        guard let missionManager = missionManager else {
            return DJIDroneTokenError.failedToInstantiateMissionManager
        }
        
        guard !missionManagerDelegate.isExecuting else {
            return DJIDroneTokenError.anotherMissionCurrentlyExecuting
        }
        
        missionManagerDelegate.resetState()
        
        var error: Error?
        let semaphore = DispatchSemaphore(value: 0)
        
        missionManager.prepare(mission, withProgress: nil) { djiError in
            error = djiError
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if error == nil {
            missionManager.startMissionExecution { djiError in
                error = djiError
                semaphore.signal()
            }
            
            semaphore.wait()
        }
        
        if error == nil {
            missionManager.startMissionExecution { djiError in
                error = djiError
                
                if error != nil {
                    self.missionManagerDelegate.isExecuting = true
                }
                
                semaphore.signal()
            }
            
            semaphore.wait()
        }
        
        while missionManagerDelegate.isExecuting {
            Thread.sleep(forTimeInterval: sleepTimeInSeconds)
        }
        
        error = missionManagerDelegate.executionError
        
        missionManagerDelegate.resetState()
        
        return error
    }

    //DJIMissionManagerDelegate

}

// MARK: - DJIDroneTokenDefaults

fileprivate struct Defaults {
    static let speed: Double = 2.0
}


// MARK: - DJIDroneTokenError

public enum DJIDroneTokenError: Error {
    case failedToInstantiateCustomMission
    case failedToInstantiateMissionManager
    case failedToInstantiateWaypointStep
    case indeterminateCurrentState
    case anotherMissionCurrentlyExecuting
}

// MARK: - FlightControllerDelegate

// DJIFlightControllerDelegates must inherit from NSObject. We can't make DJIDroneToken inherit from
// NSObject since it inherits from ExecutableTokenCard (which isn't an NSObject), so we use a private
// class for this instead.
fileprivate class FlightControllerDelegate: NSObject, DJIFlightControllerDelegate {
    var currentState: DJIFlightControllerCurrentState?
    
    func flightController(_ flightController: DJIFlightController, didUpdateSystemState state: DJIFlightControllerCurrentState) {
        self.currentState = state
    }
}

fileprivate class MissionManagerDelegate: NSObject, DJIMissionManagerDelegate {
    var progressStatus: DJIMissionProgressStatus?
    var isExecuting: Bool = false
    var executionError: Error?
    
    public func resetState() {
        progressStatus = nil
        isExecuting = false
        executionError = nil
    }
    
    public func missionManager(_ manager: DJIMissionManager, didFinishMissionExecution error: Error?) {
        if error != nil {
            print("Mission Finished with error:\(error!)")
        } else {
            print("Mission Finished!")
        }
        
        isExecuting = false
        executionError = error
    }
    
    public func missionManager(_ manager: DJIMissionManager, missionProgressStatus missionProgress: DJIMissionProgressStatus) {
        if missionProgress is DJICustomMissionStatus {
            let customMissionStatus: DJICustomMissionStatus = (missionProgress as? DJICustomMissionStatus)!
            let currentExecStep: DJIMissionStep = customMissionStatus.currentExecutingStep!
            print("Mission Status -- error: \(missionProgress.error) -- currentStep: \(currentExecStep)")
        }
        
        progressStatus = missionProgress
    }
}
