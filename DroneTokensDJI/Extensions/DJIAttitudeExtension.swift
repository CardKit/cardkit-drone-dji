/**
 * Copyright 2018 IBM Corp. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation

import DJISDK

extension DJIAttitude {
    /// Normalizes the attitude (yaw, pitch, roll) from a range of [-180, 180] to the range [0, 360].
    /// A yaw, pitch, and roll of (0, 0, 0) corresponds to an aircraft hovering level oriented toward True North.
    func normalized() -> DJIAttitude {
        let normalizedYaw = (yaw + 360).truncatingRemainder(dividingBy: 360)
        let normalizedPitch = (pitch + 360).truncatingRemainder(dividingBy: 360)
        let normalizedRoll = (roll + 360).truncatingRemainder(dividingBy: 360)
        
        return DJIAttitude(pitch: normalizedPitch, roll: normalizedRoll, yaw: normalizedYaw)
    }
}
