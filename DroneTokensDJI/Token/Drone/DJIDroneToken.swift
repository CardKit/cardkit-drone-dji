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
public class DJIDroneToken: ExecutableToken, DroneToken {
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
    
    public func spinMotors(on: Bool) throws {
        if on {
            try DispatchQueue.executeSynchronously { self.aircraft.flightController?.turnOnMotors(completion: $0) }
        } else {
            try DispatchQueue.executeSynchronously { self.aircraft.flightController?.turnOffMotors(completion: $0) }
        }
    }
    
    public func takeOff(at altitude: DCKRelativeAltitude?) throws {
        print("drone taking off and climbing to altitude \(altitude)")
        
        var missionSteps: [DJIMissionStep] = []
        
        let takeOffStep = DJITakeoffStep()
        missionSteps.append(takeOffStep)
        
        if let desiredAltitude = altitude?.metersAboveGroundAtTakeoff {
            
            guard let altitudeStep = DJIGoToStep(altitude: Float(desiredAltitude)) else {
                throw DJIDroneTokenError.failedToInstantiateCustomMission
            }
            
            missionSteps.append(altitudeStep)
        }
        
        try self.executeMissionSteps(missionSteps: missionSteps)
    }
    
    public func hover(at altitude: DCKRelativeAltitude?, withYaw yaw: DCKAngle?) throws {
        print("drone hovering at altitude: \(altitude), withYaw: \(yaw)")
        
        // stop all current missions
        // we have to check if we are currently executing a mission before we stop it, or this occurs:
        
        // (Error Domain=DJISDKMissionErrorDomain Code=-5016 "Aircraft is not running a mission or current
        // mission object in mission manager is empty.(code:-5016)" UserInfo={NSLocalizedDescription=Aircraft
        // is not running a mission or current mission object in mission manager is empty.(code:-5016)})
        if self.missionManager?.currentExecutingMission() != nil {
            try DispatchQueue.executeSynchronously { self.missionManager?.stopMissionExecution(completion: $0) }
        }
        
        try self.takeOff(at: altitude)
        
        // change yaw (if specified)
        // NOTE: WILL NEED TO LOOK AT THIS
        //this method of controlling yaw does not work
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
    }
    
    public func fly(to coordinate: DCKCoordinate2D, atYaw yaw: DCKAngle?, atAltitude altitude: DCKRelativeAltitude?, atSpeed speed: DCKSpeed?) throws {
        print("drone fly to coordinate: [\(coordinate)] atAltitude: \(altitude) atSpeed: \(speed)")
        
        if yaw != nil {
            try self.hover(withYaw: yaw)
        }
        
        let coord: CLLocationCoordinate2D = CLLocationCoordinate2DMake(coordinate.latitude, coordinate.longitude)
        
        var missionSteps: [DJIMissionStep] = []
        
        if let altitudeInMeters = altitude?.metersAboveGroundAtTakeoff,
            let altitudeStep = DJIGoToStep(altitude: Float(altitudeInMeters)) {
            missionSteps.append(altitudeStep)
        } else {
            if let currentAltitude: DCKRelativeAltitude = self.currentAltitude,
                let altitudeStep = DJIGoToStep(altitude: Float(currentAltitude.metersAboveGroundAtTakeoff)) {
                missionSteps.append(altitudeStep)
            }
        }
        
        guard let flyStep = DJIGoToStep(coordinate: coord) else {
            throw DJIDroneTokenError.failedToInstantiateCustomMission
        }
        
        if let speedInMetersPerSecond = speed?.metersPerSecond, speedInMetersPerSecond > 0 {
            flyStep.flightSpeed = Float(speedInMetersPerSecond)
        }
        missionSteps.append(flyStep)
        
        try self.executeMissionSteps(missionSteps: missionSteps)
    }
    

    public func fly(on path: DCKCoordinate2DPath, atAltitude altitude: DCKRelativeAltitude?, atSpeed speed: DCKSpeed?) throws {
      
        var altitudeInMeters: Double?
        
        // if altitude was not passed, use current altitude
        if let userSetAltitude = altitude {
            altitudeInMeters = userSetAltitude.metersAboveGroundAtTakeoff
        } else {
            guard let currentAltitude = self.flightControllerDelegate.currentState?.altitude else {
                throw DJIDroneTokenError.indeterminateCurrentState
            }
            altitudeInMeters = Double(currentAltitude)
        }
        
        if let altitudeInMeters = altitudeInMeters {
            let coordinate3DPath = path.path.map { (coordinate2d) -> DCKCoordinate3D in
                DCKCoordinate3D(latitude: coordinate2d.latitude, longitude: coordinate2d.longitude, altitude: DCKRelativeAltitude(metersAboveGroundAtTakeoff: altitudeInMeters))
            }
            try self.fly(on: DCKCoordinate3DPath(path: coordinate3DPath), atSpeed: speed)
        }
    }
    
    
    public func fly(on path: DCKCoordinate3DPath, atSpeed speed: DCKSpeed?) throws {
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
        try self.executeWaypointMission(mission: mission)
    }
    
    public func circle(around center: DCKCoordinate2D, atRadius radius: DCKDistance, atAltitude altitude: DCKRelativeAltitude, atAngularSpeed angularSpeed: DCKAngularVelocity?, atClockwise isClockwise: DCKMovementDirection?, toCircleRepeatedly toRepeat: Bool) throws {
        
        print ("drone to performing circle operation. Circle Repeatedly: \(toRepeat)")
        
        let hotPointMission: DJIHotPointMission = DJIHotPointMission()
        hotPointMission.hotPoint = CLLocationCoordinate2DMake(center.latitude, center.longitude)
        hotPointMission.radius = Float(radius.meters)
        hotPointMission.altitude = Float(altitude.metersAboveGroundAtTakeoff)
        
        if let angSpeed = angularSpeed {
            hotPointMission.angularVelocity = Float(angSpeed.degreesPerSecond)
        } else {
            // setting default angularVelocity to 20 degrees/sec
            hotPointMission.angularVelocity = Float (20.0)
        }
        
        if let isClockwise = isClockwise {
            hotPointMission.isClockwise = Bool (isClockwise.isClockwise)
        } else {
            hotPointMission.isClockwise = true
        }
        
        hotPointMission.startPoint = DJIHotPointStartPoint.nearest
        hotPointMission.heading = DJIHotPointHeading.towardHotPoint
        
        // Distinguishing mission execution of 'Circle Repeatedly' and 'Circle'.
        // DJIHotpoint mission only allows 'Circle Repeatedly'.
        // To perform single revolution of 'Circle', manual cancelling of the DJIHotPoint mission is needed.
        if toRepeat {
            try self.executeMission(mission: hotPointMission)
        } else {
            try self.executeHotPointMission(hotPointMission: hotPointMission, withRevolutionLimit: 1)
        }
    }

    public func returnHome(atAltitude altitude: DCKRelativeAltitude?, atSpeed speed: DCKSpeed?, toLand land: Bool) throws {
        print ("drone returning home atAltitude: \(altitude), atSpeed: \(speed), landAfterReturningHome: \(land)")
        
        guard let homeCoordinates = self.homeLocation else {
            throw DJIDroneTokenError.indeterminateCurrentState
        }
        
        try self.fly(to: homeCoordinates, atAltitude: altitude, atSpeed: speed)
        try self.land()
    }
    
    public func landingGear(down: Bool) throws {
        if down {
            try DispatchQueue.executeSynchronously { self.aircraft.flightController?.landingGear?.deployLandingGear(completion: $0) }
        } else {
            try DispatchQueue.executeSynchronously { self.aircraft.flightController?.landingGear?.retractLandingGear(completion: $0) }
        }
    }
    
    
    public func land() throws {
        print ("Drone landing..")
    
        /*
         Before we auto land, we need to stop any current missions. If this fails, we should
         still try to autoland. Maybe autoland will force the missions to stop executing.
         Therefore, since we are going to autoland anyways, we are ignoring the error in
         stopMissionExecution().
         */
        if self.missionManager?.currentExecutingMission() != nil {
            try DispatchQueue.executeSynchronously { self.missionManager?.stopMissionExecution(completion: $0) }
        }
        
        try DispatchQueue.executeSynchronously { self.aircraft.flightController?.autoLanding(completion: $0) }
        
        // wait for drone to reach the height to ask for landing confirmation
        while let isFlying = self.flightControllerDelegate.currentState?.isLandingConfirmationNeeded, !isFlying {
            Thread.sleep(forTimeInterval: self.sleepTimeInSeconds)
        }
        
        try DispatchQueue.executeSynchronously { self.aircraft.flightController?.confirmLanding(completion: $0) }
        
        while let isFlying = self.flightControllerDelegate.currentState?.isFlying, isFlying {
            Thread.sleep(forTimeInterval: self.sleepTimeInSeconds)
        }
    }
    
    public func spinAround(toYawAngle yaw: DCKAngle, atAngularSpeed angularSpeed: DCKAngularVelocity?) throws {
        print ("Drone spining around to change yaw angle to \(yaw) degrees at AngularSpeed: \(angularSpeed)")
        
        var missionSteps: [DJIMissionStep] = []
        
        // default angular velocity to move the drone's yaw angle is 20 degree/s according to DJI SDK
        var angSpeed: Double = 20.0
        if let angSpeedUnwrapped = angularSpeed?.degreesPerSecond, angSpeedUnwrapped > 0, angSpeedUnwrapped < 100 {
            angSpeed = angSpeedUnwrapped
        }
        
        guard let aircraftYawStep = DJIAircraftYawStep(relativeAngle: yaw.degrees, andAngularVelocity: angSpeed) else {
            throw DJIDroneTokenError.failedToInstantiateWaypointStep
        }
        
        missionSteps.append(aircraftYawStep)
        
        try self.executeMissionSteps(missionSteps: missionSteps)
        
        /*
         // Need to look in to this later to control yaw angle
         let semaphore = DispatchSemaphore(value: 0)
         
         
         let yawAngleInDegrees = 90
         var ctrlData: DJIVirtualStickFlightControlData = DJIVirtualStickFlightControlData()
         ctrlData.yaw = Float(yawAngleInDegrees)
         
         if let isVirtualStickAvailable = self.aircraft.flightController?.isVirtualStickControlModeAvailable(),
         isVirtualStickAvailable == true {
         self.aircraft.flightController?.send(ctrlData) { (djiError) in
         spinAroundError = djiError
         semaphore.signal()
         }
         }
         
         semaphore.wait()
         */
    }
    
    // MARK: - Instance Methods
    private func executeWaypointMission(mission: DJIWaypointMission) throws {
        
        // create a waypoint step
        guard let step = DJIWaypointStep(waypointMission: mission) else {
            throw DJIDroneTokenError.failedToInstantiateWaypointStep
        }
        
        // execute it
        try self.executeMissionSteps(missionSteps: [step])
    }
    
    private func executeHotPointMission(hotPointMission: DJIHotPointMission, withRevolutionLimit limit: Int) throws {
        print("Execute Hot Point Mission Sync withRevolutionLimit: \(limit)")
        
        guard let missionManager = missionManager else {
            throw DJIDroneTokenError.failedToInstantiateMissionManager
        }
        
        guard !missionManagerDelegate.isExecuting else {
            throw DJIDroneTokenError.anotherMissionCurrentlyExecuting
        }
        
        missionManagerDelegate.resetState()
        
        try DispatchQueue.executeSynchronously { missionManager.prepare(hotPointMission, withProgress: nil, withCompletion: $0) }
        
        try DispatchQueue.executeSynchronously { missionManager.startMissionExecution(completion: $0) }
        
        missionManagerDelegate.isExecuting = true
        var startPointLocation: DCKCoordinate2D?
        var prevDistance: Double?
        var isPrevSlopePositive: Bool = true
        var revolutionCounter: Int = 0
        
        while missionManagerDelegate.isExecuting {
            if let status: DJIHotPointMissionStatus = missionManagerDelegate.progressStatus as? DJIHotPointMissionStatus {
                if status.executionState == DJIHotpointMissionExecutionState.initializing {
                    print ("DJI Hot Point Mission status: flying to the nearest starting point")
                } else if status.executionState == DJIHotpointMissionExecutionState.moving {
                    
                    // guard current location
                    guard let currentLocation: DCKCoordinate2D = self.currentLocation else {
                        print ("DJI Hot Point Mission status: cannot determine current location. Aborting mission.")
                        try DispatchQueue.executeSynchronously { missionManager.stopMissionExecution(completion: $0) }
                        throw DJIDroneTokenError.indeterminateCurrentState
                    }
                    
                    // two ways you can check whether the revolution has completed
                    // Method 1: Use angular velocity
                    // Sleep until the num of revolution is completed
                    /*
                     startPointLocation = DCKCoordinate2D(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
                     let sleepTime: Double = Double(360.0/hotPointMission.angularVelocity) * Double(limit)
                     Thread.sleep(forTimeInterval: sleepTime)
                     print ("DJI Hot Point Mission status: \(limit) revolution has completed.")
                     self.missionManager?.stopMissionExecution { (djiError) in
                     semaphore.signal()
                     error = djiError
                     }
                     
                     semaphore.wait()
                     */
                    
                    // Method 2
                    if startPointLocation == nil {
                        startPointLocation = DCKCoordinate2D(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
                    } else {
                        
                        // this error should never happen
                        guard let startPoint: DCKCoordinate2D = startPointLocation else {
                            print ("DJI Hot Point Mission status: cannot determine the circle starting location. Aborting mission.")
                            try DispatchQueue.executeSynchronously { missionManager.stopMissionExecution(completion: $0) }
                            throw DJIDroneTokenError.indeterminateCurrentState
                        }
                        
                        let distance: Double = currentLocation.distance(to: startPoint)
                        if let prevDistance = prevDistance {
                            let changeInDistance: Double = distance - prevDistance
                            if changeInDistance < 0 {
                                isPrevSlopePositive = false
                            } else {
                                if isPrevSlopePositive == false {
                                    revolutionCounter += 1
                                    if revolutionCounter == limit {
                                        print ("DJI Hot Point Mission status: \(limit) revolution has completed. Distance: \(distance)")
                                        try DispatchQueue.executeSynchronously { missionManager.stopMissionExecution(completion: $0) }
                                    } else {
                                        print ("DJI Hot Point Mission status: \(revolutionCounter) revolution has completed. Remaining # of revolution: \(limit-revolutionCounter)")
                                        
                                    }
                                }
                                isPrevSlopePositive = true
                            }
                            
                        } else {
                            prevDistance = distance
                        }
                        print ("DJI Hot Point Mission status: Circling. Distance from Starting Point: \(distance)")
                        
                    }
                }
            }
            Thread.sleep(forTimeInterval: sleepTimeInSeconds)
        }
        
        missionManagerDelegate.resetState()
        
        if let error = missionManagerDelegate.executionError {
            throw error
        }
    }
    
    private func executeMissionSteps(missionSteps: [DJIMissionStep]) throws {
        guard let mission = DJICustomMission(steps: missionSteps) else {
            throw DJIDroneTokenError.failedToInstantiateCustomMission
        }
        
        try self.executeMission(mission: mission)
    }
    
    private func executeMission(mission: DJIMission) throws {
        print("Execute Mission Sync")
        guard let missionManager = missionManager else {
            throw DJIDroneTokenError.failedToInstantiateMissionManager
        }
        
        guard !missionManagerDelegate.isExecuting else {
            throw DJIDroneTokenError.anotherMissionCurrentlyExecuting
        }
        
        missionManagerDelegate.resetState()
        
        
        try DispatchQueue.executeSynchronously { missionManager.prepare(mission, withProgress: nil, withCompletion: $0) }
        
        try DispatchQueue.executeSynchronously { missionManager.startMissionExecution(completion: $0) }
        missionManagerDelegate.isExecuting = true
        
        while missionManagerDelegate.isExecuting {
            Thread.sleep(forTimeInterval: sleepTimeInSeconds)
        }
        
        missionManagerDelegate.resetState()
        
        if let error = missionManagerDelegate.executionError {
            throw error
        }
    }
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
// NSObject since it inherits from ExecutableToken (which isn't an NSObject), so we use a private
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
        if let error = error {
            print("Mission Finished with error:\(error)")
        } else {
            print("Mission Finished!")
        }
        
        isExecuting = false
        executionError = error
    }
    
    public func missionManager(_ manager: DJIMissionManager, missionProgressStatus missionProgress: DJIMissionProgressStatus) {
        if missionProgress is DJICustomMissionStatus,
            let customMissionStatus: DJICustomMissionStatus = (missionProgress as? DJICustomMissionStatus),
            let currentExecStep: DJIMissionStep = customMissionStatus.currentExecutingStep {
            print("Mission Status -- error: \(missionProgress.error) -- currentStep: \(currentExecStep)")
        }
        
        progressStatus = missionProgress
    }
}
