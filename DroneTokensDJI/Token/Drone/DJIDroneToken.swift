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
        
        return DCKAttitude(yaw: DCKAngle(degrees: attitude.yaw), pitch: DCKAngle(degrees: attitude.pitch), roll: DCKAngle(degrees: attitude.roll))
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
    
    // MARK: init
    
    public init(with card: TokenCard, for aircraft: DJIAircraft) {
        self.aircraft = aircraft
        self.aircraft.flightController?.delegate = self.flightControllerDelegate
        missionManager?.delegate = missionManagerDelegate
        super.init(with: card)
    }
    
    // MARK: Instance Methods
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
        
        executeMissionSteps(missionSteps: missionSteps) { (djiError) in
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
            
            completionHandler?(error)
        }
    }
    
    public func fly(to coordinate: DCKCoordinate2D, atYaw yaw: DCKAngle?, atAltitude altitude: DCKRelativeAltitude?, atSpeed speed: DCKSpeed?, completionHandler: AsyncExecutionCompletionHandler?) {
        print("drone fly to coordinate: [\(coordinate)] atAltitude: \(altitude) atSpeed: \(speed)")
        
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
                } else {
                    if let currentAltitude: DCKRelativeAltitude = self.currentAltitude,
                        let altitudeStep = DJIGoToStep(altitude: Float(currentAltitude.metersAboveGroundAtTakeoff)) {
                        missionSteps.append(altitudeStep)
                    }
                }
                
                
                if let flyStep = DJIGoToStep(coordinate: coord) {
                    if let speedInMetersPerSecond = speed?.metersPerSecond, speedInMetersPerSecond > 0 {
                        flyStep.flightSpeed = Float(speedInMetersPerSecond)
                    } else {
                        // default speed 4 meters/second.
                        // we can change it later
                        //flyStep.flightSpeed = Float (4)
                    }
                    
                    missionSteps.append(flyStep)
                } else {
                    error = DJIDroneTokenError.failedToInstantiateCustomMission
                    semaphore.signal()
                }
                
                self.executeMissionSteps(missionSteps: missionSteps) { (djiError) in
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
    
    public func circle(around center: DCKCoordinate2D, atRadius radius: DCKDistance, atAltitude altitude: DCKRelativeAltitude, atAngularSpeed angularSpeed: DCKAngularVelocity?, atClockwise isClockwise:DCKMovementDirection?, toCircleRepeatedly toRepeat:Bool, completionHandler: AsyncExecutionCompletionHandler?) {
        print ("drone to performing circle operation. Circle Repeatedly: \(toRepeat)")
        
        DispatchQueue.global(qos: .default).async {
            let semaphore = DispatchSemaphore(value: 0)
            var error: Error? = nil
            
            // fly to location
            if error == nil {
                
                var hotPointMission: DJIHotPointMission = DJIHotPointMission()
                hotPointMission.hotPoint=CLLocationCoordinate2DMake(center.latitude, center.longitude)
                hotPointMission.radius=Float(radius.meters)
                hotPointMission.altitude=Float(altitude.metersAboveGroundAtTakeoff)
                
                if let angSpeed = angularSpeed
                {
                    hotPointMission.angularVelocity = Float(angSpeed.degreesPerSecond)
                }
                else {
                    hotPointMission.angularVelocity=20.0
                }
                
                if let isClockwiseDirection = isClockwise
                {
                    hotPointMission.isClockwise = Bool (isClockwiseDirection.isClockwise)
                }
                else {
                    hotPointMission.isClockwise=true
                }
                
                hotPointMission.startPoint=DJIHotPointStartPoint.nearest
                hotPointMission.heading=DJIHotPointHeading.towardHotPoint
                
                // Distinguishing mission execution of 'Circle Repeatedly' and 'Circle'.
                // DJIHotpoint mission only allows 'Circle Repeatedly'. 
                // To perform single revolution of 'Circle', manual cancelling of the DJIHotPoint mission is needed.
                if (toRepeat)
                {
                    self.executeMission(mission: hotPointMission) { (djiError) in
                        error = djiError
                        semaphore.signal()
                    }
                    semaphore.wait()
                }
                else
                {
                    self.executeHotPointMissionWithCancelAfterRevolution(hotPointMission: hotPointMission, numOfRevolution: 1) { (djiError) in
                        error = djiError
                        semaphore.signal()
                    }
                    semaphore.wait()
                    
                }
            }
            
            completionHandler?(error)
        }
    }

    
    public func flyBackHome(atAltitude altitude: DCKRelativeAltitude?, atSpeed speed: DCKSpeed?, completionHandler: AsyncExecutionCompletionHandler?) {
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
        print ("Drone landing..")
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
            
            // wait for drone to reach the height to ask for landing confirmation
            // TODO: fix the busy wait
            if error == nil {
                while let isFlying = self.flightControllerDelegate.currentState?.isLandingConfirmationNeeded, !isFlying {
                    Thread.sleep(forTimeInterval: self.sleepTimeInSeconds)
                }
            }
            if error == nil {
                self.aircraft.flightController?.confirmLanding(completion: { (djiError) in
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
        return executeMissionSteps(missionSteps: [step], completionHandler: completionHandler)
    }
 
    
    private func executeMissionSteps(missionSteps: [DJIMissionStep], completionHandler: AsyncExecutionCompletionHandler?) {
        DispatchQueue.global(qos: .default).async {
            guard let mission = DJICustomMission(steps: missionSteps) else {
                let error=DJIDroneTokenError.failedToInstantiateCustomMission
                completionHandler?(error)
                return
            }
            
            let error = self.executeMissionSync(mission: mission)
            completionHandler?(error)
        }
    }
    
    private func executeHotPointMissionWithCancelAfterRevolution(hotPointMission: DJIHotPointMission, numOfRevolution: Int, completionHandler: AsyncExecutionCompletionHandler?) {
        DispatchQueue.global(qos: .default).async {
            let error = self.executeHotPointMissionWithCancelAfterRevolutionSync(hotPointMission: hotPointMission, numOfRevolution: numOfRevolution)
            completionHandler?(error)
        }
    }
    
    private func executeHotPointMissionWithCancelAfterRevolutionSync(hotPointMission: DJIHotPointMission, numOfRevolution: Int) -> Error? {
        print("Execute Hot Point Mission Sync with Cancel after \(numOfRevolution) revolution")
        
        guard let missionManager = missionManager else {
            
            return DJIDroneTokenError.failedToInstantiateMissionManager
        }
        
        guard !missionManagerDelegate.isExecuting else {
            
            return DJIDroneTokenError.anotherMissionCurrentlyExecuting
        }
        
        missionManagerDelegate.resetState()
        
        var error: Error?
        let semaphore = DispatchSemaphore(value: 0)
        
        missionManager.prepare(hotPointMission, withProgress: nil) { djiError in
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
        
        var startPointLocation: DCKCoordinate2D?
        var prevDistance: Double?
        var isPrevSlopePositive: Bool = true
        var revolutionCounter: Int = 0
        
        while missionManagerDelegate.isExecuting {
            if let status:DJIHotPointMissionStatus=missionManagerDelegate.progressStatus as? DJIHotPointMissionStatus {
                if (status.executionState==DJIHotpointMissionExecutionState.initializing)
                {
                    print ("DJI Hot Point Mission status: flying to the nearest starting point")
                }
                else if (status.executionState==DJIHotpointMissionExecutionState.moving)
                {
                    // guard current location
                    guard let currentLocation: DCKCoordinate2D = self.currentLocation else {
                        print ("DJI Hot Point Mission status: cannot determine current location. Aborting mission.")
                        self.missionManager?.stopMissionExecution { (djiError) in
                            semaphore.signal()
                            error = djiError
                        }
                        
                        semaphore.wait()
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
                    if (startPointLocation==nil) {
                        startPointLocation = DCKCoordinate2D(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
                    }
                    else
                    {
                        // this error should never happen
                        guard let startPoint: DCKCoordinate2D = startPointLocation else {
                            print ("DJI Hot Point Mission status: cannot determine the circle starting location. Aborting mission.")
                            self.missionManager?.stopMissionExecution { (djiError) in
                                semaphore.signal()
                                error = djiError
                            }
                            semaphore.wait()
                            return DroneTokenError.FailureRetrievingDroneState
                        }
                        
                        let distance:Double=computeDistanceBetweenTwoCoordinate(location1: currentLocation, location2: startPoint)
                        if let prevD: Double = prevDistance
                        {
                            let changeInDistance: Double = distance-prevD
                            if (changeInDistance<0) {
                                isPrevSlopePositive=false
                            } else {
                                if (isPrevSlopePositive==false) {
                                    revolutionCounter += 1
                                    if (revolutionCounter == numOfRevolution)
                                    {
                                        print ("DJI Hot Point Mission status: \(numOfRevolution) revolution has completed. Distance: \(distance)")
                                        self.missionManager?.stopMissionExecution { (djiError) in
                                            semaphore.signal()
                                            error = djiError
                                        }
                                        
                                        semaphore.wait()
                                    }
                                    else {
                                        print ("DJI Hot Point Mission status: \(revolutionCounter) revolution has completed. Remaining # of revolution: \(numOfRevolution-revolutionCounter)")
                                        
                                    }
                                }
                                isPrevSlopePositive=true
                            }
                            
                        }
                        else {
                            prevDistance=distance
                        }
                        print ("DJI Hot Point Mission status: Circling. Distance from Starting Point: \(distance)")
                        
                    }
                }
            }
            Thread.sleep(forTimeInterval: sleepTimeInSeconds)
        }
        
        error = missionManagerDelegate.executionError
        
        missionManagerDelegate.resetState()
        
        return error
    }
    
    // helper method for computeDistanceBetweenTwoCoordinate method. 
    // converts Degree to Radians
    private func deg2rad(deg: Double) -> Double {
        return deg * (M_PI/180)
    }
    
    // using Haversine formula to determine the distance (meters) between two GPS coordinates
    private func computeDistanceBetweenTwoCoordinate(location1: DCKCoordinate2D, location2: DCKCoordinate2D) -> Double {
        let lat1=location1.latitude
        let lon1=location1.longitude
        let lat2=location2.latitude
        let lon2=location2.longitude
        
        let R:Double = 6371 // Radius of the earth in km
        let dLat = deg2rad(deg: lat2-lat1)  // deg2rad below
        let dLon = deg2rad(deg: lon2-lon1)
        let a = sin(dLat/2) * sin(dLat/2) + cos(deg2rad(deg: lat1)) * cos(deg2rad(deg: lat2)) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        let d:Double = R * c // Distance in km
        return d*1000 // Distance in meters
    }
    
    private func executeMission(mission: DJIMission, completionHandler: AsyncExecutionCompletionHandler?) {
        DispatchQueue.global(qos: .default).async {
            let error = self.executeMissionSync(mission: mission)
            completionHandler?(error)
        }
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
