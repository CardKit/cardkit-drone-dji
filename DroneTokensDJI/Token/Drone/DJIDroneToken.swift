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
        
        DispatchQueue.global(qos: .default).async {
            
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
            
            let error = self.executeMissionStepsSync(missionSteps: missionSteps)
            completionHandler?(error)
        }
    }
    
    public func hover(at altitude: DCKRelativeAltitude?, withYaw yaw: DCKAngle?, completionHandler: AsyncExecutionCompletionHandler?) {
        print("drone hovering at altitude: \(altitude), withYaw: \(yaw)")
        
        DispatchQueue.global(qos: .default).async {
            
            // stop all current missions
            // we have to check if we are currently executing a mission before we stop it, or this occurs:
            
            // (Error Domain=DJISDKMissionErrorDomain Code=-5016 "Aircraft is not running a mission or current
            // mission object in mission manager is empty.(code:-5016)" UserInfo={NSLocalizedDescription=Aircraft
            // is not running a mission or current mission object in mission manager is empty.(code:-5016)})
            var hoverError: Error? = nil
            
            do {
                if self.missionManager?.currentExecutingMission() != nil {
                    try DispatchQueue.executeSynchronously { self.missionManager?.stopMissionExecution(completion: $0) }
                }
                
                try DispatchQueue.executeSynchronously { self.takeOff(at: altitude, completionHandler: $0) }
            } catch {
                hoverError = error
            }

            
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
            
            completionHandler?(hoverError)
        }
    }
    
    public func fly(to coordinate: DCKCoordinate2D, atYaw yaw: DCKAngle?, atAltitude altitude: DCKRelativeAltitude?, atSpeed speed: DCKSpeed?, completionHandler: AsyncExecutionCompletionHandler?) {
        print("drone fly to coordinate: [\(coordinate)] atAltitude: \(altitude) atSpeed: \(speed)")
        
        DispatchQueue.global(qos: .default).async {
            var flyError: Error? = nil
            
            do {
                if yaw != nil {
                    try DispatchQueue.executeSynchronously { self.hover(withYaw: yaw, completionHandler: $0) }
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
                
                if let flyStep = DJIGoToStep(coordinate: coord) {
                    if let speedInMetersPerSecond = speed?.metersPerSecond, speedInMetersPerSecond > 0 {
                        flyStep.flightSpeed = Float(speedInMetersPerSecond)
                    }
                    missionSteps.append(flyStep)
                } else {
                    flyError = DJIDroneTokenError.failedToInstantiateCustomMission
                    completionHandler?(flyError)
                    return
                }
                
                flyError = self.executeMissionStepsSync(missionSteps: missionSteps)
                
            } catch {
                flyError = error
            }

            completionHandler?(flyError)
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
        
        DispatchQueue.global(qos: .default).async {
            
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
            let error = self.executeWaypointMissionSync(mission: mission)
            completionHandler?(error)
        }
    }
    
    public func circle(around center: DCKCoordinate2D, atRadius radius: DCKDistance, atAltitude altitude: DCKRelativeAltitude, atAngularSpeed angularSpeed: DCKAngularVelocity?, atClockwise isClockwise: DCKMovementDirection?, toCircleRepeatedly toRepeat: Bool, completionHandler: AsyncExecutionCompletionHandler?) {
        print ("drone to performing circle operation. Circle Repeatedly: \(toRepeat)")
        
        DispatchQueue.global(qos: .default).async {
            var error: Error? = nil
            
            // fly to location
            if error == nil {
                
                let hotPointMission: DJIHotPointMission = DJIHotPointMission()
                hotPointMission.hotPoint = CLLocationCoordinate2DMake(center.latitude, center.longitude)
                hotPointMission.radius = Float(radius.meters)
                hotPointMission.altitude = Float(altitude.metersAboveGroundAtTakeoff)
                
                if let angSpeed = angularSpeed {
                    hotPointMission.angularVelocity = Float(angSpeed.degreesPerSecond)
                } else {
                    hotPointMission.angularVelocity = 20.0
                }
                
                if let isClockwiseDirection = isClockwise {
                    hotPointMission.isClockwise = Bool (isClockwiseDirection.isClockwise)
                } else {
                    hotPointMission.isClockwise = true
                }
                
                hotPointMission.startPoint = DJIHotPointStartPoint.nearest
                hotPointMission.heading = DJIHotPointHeading.towardHotPoint
                
                // Distinguishing mission execution of 'Circle Repeatedly' and 'Circle'.
                // DJIHotpoint mission only allows 'Circle Repeatedly'. 
                // To perform single revolution of 'Circle', manual cancelling of the DJIHotPoint mission is needed.
                if toRepeat {
                    error = self.executeMissionSync(mission: hotPointMission)
                } else {
                    error = self.executeHotPointMissionWithNumOfRevolutionSync(hotPointMission: hotPointMission, numOfRevolution: 1)
                }
            }
            
            completionHandler?(error)
        }
    }
   
    public func returnHome(atAltitude altitude: DCKRelativeAltitude?, atSpeed speed: DCKSpeed?, toLand land: Bool, completionHandler: AsyncExecutionCompletionHandler?) {
        print ("drone returning home atAltitude: \(altitude), atSpeed: \(speed), landAfterReturningHome: \(land)")
        
        DispatchQueue.global(qos: .default).async {
            
            guard let homeCoordinates = self.homeLocation else {
                completionHandler?(DroneTokenError.FailureRetrievingDroneState)
                return
            }
            
            var returnHomeError: Error? = nil
            
            do {
                try DispatchQueue.executeSynchronously { self.fly(to: homeCoordinates, atAltitude: altitude, atSpeed: speed, completionHandler: $0) }
                try DispatchQueue.executeSynchronously { self.land(completionHandler: $0) }
            } catch {
                returnHomeError = error
            }

            completionHandler?(returnHomeError)
        }
    }
    
    public func landingGear(down: Bool, completionHandler: AsyncExecutionCompletionHandler?) {
        if down {
            aircraft.flightController?.landingGear?.deployLandingGear(completion: completionHandler)
        } else {
            aircraft.flightController?.landingGear?.retractLandingGear(completion: completionHandler)
        }
    }
    
    
    public func land(completionHandler: AsyncExecutionCompletionHandler?) {
        print ("Drone landing..")
        
        DispatchQueue.global(qos: .default).async {
            var landError: Error?
            
            do {
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
            } catch {
                landError = error
            }
            
            completionHandler?(landError)
        }
    }
    
    public func spinAround(toYawAngle yaw: DCKAngle, atAngularSpeed angularSpeed: DCKAngularVelocity?, completionHandler: AsyncExecutionCompletionHandler?) {
        print ("Drone spining around to change yaw angle to \(yaw) degrees at AngularSpeed: \(angularSpeed)")
        
        DispatchQueue.global(qos: .default).async {
            var spinAroundError: Error? = nil
            
            var missionSteps: [DJIMissionStep] = []
         
            // default angular velocity to move the drone's yaw angle is 20 degree/s according to DJI SDK
            var angSpeed: Double = 20.0
            if let angSpeedUnwrapped = angularSpeed?.degreesPerSecond, angSpeedUnwrapped > 0, angSpeedUnwrapped < 100 {
                angSpeed = angSpeedUnwrapped
            }

            if let aircraftYawStep = DJIAircraftYawStep(relativeAngle: yaw.degrees, andAngularVelocity: angSpeed) {
                missionSteps.append(aircraftYawStep)
            } else {
                spinAroundError = DJIDroneTokenError.failedToInstantiateCustomMission
                completionHandler?(spinAroundError)
                return
            }
            
            // spinAroundError = self.executeMissionStepsSync(missionSteps: missionSteps)
            
            /*
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
       
            completionHandler?(spinAroundError)
        }

    }

    // MARK: - Instance Methods
    private func executeWaypointMissionSync(mission: DJIWaypointMission) -> Error? {
        
        // create a waypoint step
        guard let step = DJIWaypointStep(waypointMission: mission) else {
            return DJIDroneTokenError.failedToInstantiateWaypointStep
        }
        
        // execute it
        return executeMissionStepsSync(missionSteps: [step])
    }
 
    private func executeHotPointMissionWithNumOfRevolutionSync(hotPointMission: DJIHotPointMission, numOfRevolution: Int) -> Error? {
        print("Execute Hot Point Mission Sync with Num of Revolution: \(numOfRevolution)")
        
        guard let missionManager = missionManager else {
            return DJIDroneTokenError.failedToInstantiateMissionManager
        }
        
        guard !missionManagerDelegate.isExecuting else {
            return DJIDroneTokenError.anotherMissionCurrentlyExecuting
        }
        
        missionManagerDelegate.resetState()
      
        do {
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
                            return DroneTokenError.FailureRetrievingDroneState
                        }
                        
                        
                        
                        // two ways you can check whether the revolution has completed
                        // Method 1: Use angular velocity
                        // Sleep until the num of revolution is completed
                        /*
                         startPointLocation = DCKCoordinate2D(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
                         let sleepTime: Double = Double(360.0/hotPointMission.angularVelocity) * Double(numOfRevolution)
                         Thread.sleep(forTimeInterval: sleepTime)
                         print ("DJI Hot Point Mission status: \(numOfRevolution) revolution has completed.")
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
                                return DroneTokenError.FailureRetrievingDroneState
                            }
                            
                            let distance: Double = currentLocation.distance(to: startPoint)
                            if let prevD: Double = prevDistance {
                                let changeInDistance: Double = distance-prevD
                                if changeInDistance < 0 {
                                    isPrevSlopePositive = false
                                } else {
                                    if isPrevSlopePositive == false {
                                        revolutionCounter += 1
                                        if revolutionCounter == numOfRevolution {
                                            print ("DJI Hot Point Mission status: \(numOfRevolution) revolution has completed. Distance: \(distance)")
                                            try DispatchQueue.executeSynchronously { missionManager.stopMissionExecution(completion: $0) }
                                        } else {
                                            print ("DJI Hot Point Mission status: \(revolutionCounter) revolution has completed. Remaining # of revolution: \(numOfRevolution-revolutionCounter)")
                                            
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
        } catch {
            return error
        }

        missionManagerDelegate.resetState()

        return missionManagerDelegate.executionError
    }
    
    private func executeMissionStepsSync(missionSteps: [DJIMissionStep]) -> Error? {
        guard let mission = DJICustomMission(steps: missionSteps) else {
            let error = DJIDroneTokenError.failedToInstantiateCustomMission
            return error
        }
        
        let error = self.executeMissionSync(mission: mission)
        return error
    }
    
    private func executeMissionSync(mission: DJIMission) -> Error? {
        print("Execute Mission Sync")
        guard let missionManager = missionManager else {
            
            return DJIDroneTokenError.failedToInstantiateMissionManager
        }
        
        guard !missionManagerDelegate.isExecuting else {
            
            return DJIDroneTokenError.anotherMissionCurrentlyExecuting
        }
        
        missionManagerDelegate.resetState()
        
        do {
            try DispatchQueue.executeSynchronously { missionManager.prepare(mission, withProgress: nil, withCompletion: $0) }
        
            try DispatchQueue.executeSynchronously { missionManager.startMissionExecution(completion: $0) }
            missionManagerDelegate.isExecuting = true
        } catch {
            return error
        }
        
        while missionManagerDelegate.isExecuting {
            Thread.sleep(forTimeInterval: sleepTimeInSeconds)
        }

        missionManagerDelegate.resetState()

        return missionManagerDelegate.executionError
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
