// Copyright 2021-22 Jean Bovet
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import Foundation

/// This class handles various the speed limit computation necessary to ensure a train
/// moves smoothly across the layout while ensuring a safe speed to allow to brake within
/// the available braking distance.
struct LayoutSpeed {
    let layout: Layout

    /// Returns true if the train can stop within the available lead distance, including any remaining distance
    /// in the specified block, at the specified speed.
    ///
    /// The leading distance is the distance of all the reserved leading blocks in front of the train.
    /// The goal is to ensure that a train can stop safely at any moment with the leading distance
    /// available - otherwise, it might overshoot the leading blocks in case a stop is requested.
    ///
    /// - Parameters:
    ///   - train: the train
    ///   - block: the block
    ///   - speed: the speed to evaluate
    /// - Returns: true if the train can stop with the available leading distance, false otherwise
    func isBrakingDistanceRespected(train: Train, block: Block, speed: SpeedKph) throws -> Bool {
        let distanceLeftInBlock = train.distanceLeftInFrontBlock(frontBlock: block)
        let leadingDistance = distanceLeftInBlock + train.leading.settledDistance

        // Special case if the speed is 0 and the leading distance is 0,
        // the train should not be allowed to move forward.
        // TODO: add unit test for this
        if leadingDistance == 0, speed == 0 {
            return false
        }

        // Compute the distance necessary to bring the train to a full stop
        let result = try distanceNeededToChangeSpeed(ofTrain: train, fromSpeed: speed, toSpeed: 0)

        // The braking distance is respected if it is shorter or equal to the leading distance available.
        let respected = result.distance <= leadingDistance

        // Debug message
        var message: String
        if respected {
            message = "can come to a full stop in "
        } else {
            message = "⚠️ cannot come to a full stop in "
        }
        message += result.distance.distanceString
        message += " (in \(result.duration.durationString))"

        message += " at \(speed.speedString)."
        message += " The leading distance is \(leadingDistance.distanceString) with blocks \(train.leading.blocks.toStrings())"
        message += " and \(distanceLeftInBlock.distanceString) left in block."
        BTLogger.router.debug("\(train.description(layout), privacy: .public): \(message, privacy: .public)")

        return respected
    }

    /// Returns the maximum speed allowed for the train, given its occupied and leading items.
    ///
    /// The following rules are applied:
    /// - Restricted speed limit on occupied items (blocks or turnouts) are applied immediately.
    /// - The settled lead distance is used to compute the speed to safely brake in the available distance.
    /// - The lead distance to the first restricted lead item (for example, a turnout) is used to compute the speed to safely brake.
    ///
    /// - Parameters:
    ///     - train: the train
    ///     - frontBlock: the block at the front of the train
    /// - Returns: the maximum allowed speed
    func maximumSpeedAllowed(train: Train, frontBlock: Block) throws -> SpeedKph {
        var maximumSpeedAllowed = LayoutFactory.DefaultMaximumSpeed

        maximumSpeedAllowed = min(maximumSpeedAllowed, occupiedBlocksMaximumSpeed(train: train))
        maximumSpeedAllowed = min(maximumSpeedAllowed, try unrestrictedLeadMaximumSpeed(train: train, frontBlock: frontBlock))
        maximumSpeedAllowed = min(maximumSpeedAllowed, try settledLeadMaximumSpeed(train: train, frontBlock: frontBlock))

        BTLogger.router.debug("\(train.description(layout), privacy: .public): maximum allowed speed is \(maximumSpeedAllowed)kph")

        return maximumSpeedAllowed
    }

    /// Returns the maximum speed allowed in the blocks (and turnouts) occupied by the train.
    /// This takes into account speed limits for turnout branches and more.
    /// - Parameter train: the train
    /// - Returns: the maximum allowed speed
    func occupiedBlocksMaximumSpeed(train: Train) -> SpeedKph {
        var maximumSpeedAllowed: SpeedKph = LayoutFactory.DefaultMaximumSpeed
        for block in train.occupied.blocks {
            maximumSpeedAllowed = block.maximumSpeedAllowed(speed: maximumSpeedAllowed)
        }
        for turnout in train.occupied.turnouts {
            maximumSpeedAllowed = turnout.maximumSpeedAllowed(speed: maximumSpeedAllowed)
        }
        return maximumSpeedAllowed
    }

    /// Returns the maximum speed allowed by the available distance to the first restricted speed limit lead item.
    ///
    /// This is done by computing the distance of the lead items (blocks and turnouts) until one item is found to have
    /// a speed limit (like a turnout that has a branch state). The speed is computed by taking into account that distance.
    ///
    /// This is to ensure that, for example, if there is a turnout in the lead items that has a speed restriction, this speed restriction
    /// is taken into account but not if there is enough distance to brake the train. Otherwise, the train will move in a restricted
    /// speed as soon as one leading element, such as a turnout, has a branching state while the train still has ample space to
    /// brake within the block it is currently moving in.
    /// - Parameters:
    ///     - train: the train
    ///     - frontBlock: the block at the front of the train
    /// - Returns: the maximum speed
    func unrestrictedLeadMaximumSpeed(train: Train, frontBlock: Block) throws -> SpeedKph {
        let distanceLeftInBlock = train.distanceLeftInFrontBlock(frontBlock: frontBlock)
        var unrestrictedLeadingDistance = distanceLeftInBlock
        var speed = LayoutFactory.DefaultMaximumSpeed
        for item in train.leading.items {
            let distance: Double
            switch item {
            case let .block(block):
                speed = block.maximumSpeedAllowed(speed: speed)
                distance = block.length ?? 0

            case let .turnout(turnout):
                speed = turnout.maximumSpeedAllowed(speed: speed)
                distance = turnout.length ?? 0

            case .transition:
                distance = 0
            }

            if speed < LayoutFactory.DefaultMaximumSpeed {
                // We stop as soon as a speed restriction is found.
                // The distance we have accumulated so far is going to
                // be used below to compute the maximum speed.
                let maxSpeed = try maximumSpeedToBrake(train: train, toSpeed: speed, withDistance: unrestrictedLeadingDistance)

                // The resulting speed cannot be greater than the actual speed value,
                // because the actual speed value is already limited by the block or turnout specifications.
                return min(speed, maxSpeed)
            } else {
                unrestrictedLeadingDistance += distance
            }
        }

        return speed
    }

    /// Returns the maximum speed allowed to safely change the speed of the train to the specified target speed given the distance available.
    ///
    /// Note that the resulting speed can be slower than the default braking speed if necessary.
    ///
    /// - Parameters:
    ///   - train: the train
    ///   - speed: the desired target speed
    ///   - distance: the distance available to change the train speed
    /// - Returns: the maximum speed to brake within the distance
    private func maximumSpeedToBrake(train: Train, toSpeed speed: SpeedKph, withDistance distance: Double) throws -> SpeedKph {
        let maxSpeeds = [LayoutFactory.DefaultMaximumSpeed, LayoutFactory.DefaultLimitedSpeed, LayoutFactory.DefaultBrakingSpeed]
        var brakingDistance = DistanceChangeResult(distance: 0, duration: 0)
        for maxSpeed in maxSpeeds {
            brakingDistance = try distanceNeededToChangeSpeed(ofTrain: train, fromSpeed: maxSpeed, toSpeed: speed)
            guard brakingDistance.distance > distance else {
                return maxSpeed
            }
        }

        guard let lastMaxSpeed = maxSpeeds.last else {
            return 0
        }

        var maxSpeed = lastMaxSpeed / 2
        while brakingDistance.distance > distance, maxSpeed > 0 {
            brakingDistance = try distanceNeededToChangeSpeed(ofTrain: train, fromSpeed: maxSpeed, toSpeed: speed)
            if brakingDistance.distance <= distance {
                return maxSpeed
            } else {
                maxSpeed = maxSpeed / 2
            }
        }

        return maxSpeed
    }

    /// Returns the maximum speed allowed by the available lead settled distance, including the distance left
    /// in the current block.
    ///
    /// - Parameters:
    ///     -  train: the train
    ///     - frontBlock: the block at the front of the train
    /// - Returns: the maximum speed
    func settledLeadMaximumSpeed(train: Train, frontBlock: Block) throws -> SpeedKph {
        let distanceLeftInBlock = train.distanceLeftInFrontBlock(frontBlock: frontBlock)
        let settledDistance = distanceLeftInBlock + train.leading.settledDistance
        return try maximumSpeedToBrake(train: train, toSpeed: 0, withDistance: settledDistance)
    }

    struct DistanceChangeResult {
        /// The distance in cm
        let distance: Double
        /// The duration in seconds
        let duration: TimeInterval
    }

    /// Returns the distance needed to change the speed from one speed to another speed.
    ///
    /// The computation uses the duration it takes to brake the train from one speed to another
    /// using the number of decoder steps necessary as well as the time per step.
    ///
    /// - Parameters:
    ///   - train: the train
    ///   - fromSpeed: the original speed
    ///   - toSpeed: the desired speed
    /// - Returns: the resulting distance and duration
    func distanceNeededToChangeSpeed(ofTrain train: Train, fromSpeed: SpeedKph, toSpeed: SpeedKph) throws -> DistanceChangeResult {
        guard let loc = train.locomotive else {
            throw LayoutError.locomotiveNotAssignedToTrain(train: train)
        }

        // Compute the duration it will take to change the speed of the train
        var delaySeconds = LayoutSpeed.durationToChange(speed: loc.speed, fromSpeed: fromSpeed, toSpeed: toSpeed)
        guard delaySeconds > 0 else {
            return DistanceChangeResult(distance: 0, duration: 0)
        }

        // If we are stopping the train, we need to take into account the time it takes to effectively stop it
        if toSpeed == 0 {
            delaySeconds += loc.speed.stopSettleDelay
        }

        // Compute the distance it will take to change the speed given the duration and current speed
        let distanceH0cm: DistanceCm = LayoutSpeed.distance(atSpeed: fromSpeed, forDuration: delaySeconds)

        return DistanceChangeResult(distance: distanceH0cm, duration: delaySeconds)
    }

    /// Returns the duration, in seconds, that it takes to change the speed from one value to another.
    ///
    /// - Parameters:
    ///   - speed: the locomotive speed
    ///   - fromSpeed: the starting speed value
    ///   - toSpeed: the target speed value
    /// - Returns: the duration in seconds
    static func durationToChange(speed: LocomotiveSpeed, fromSpeed: SpeedKph, toSpeed: SpeedKph) -> TimeInterval {
        let fromSteps = speed.steps(for: fromSpeed).value
        let toSteps = speed.steps(for: toSpeed).value
        let steps = fromSteps - toSteps

        guard steps != 0 else {
            return 0
        }

        let stepSize = speed.accelerationStepSize ?? LocomotiveSpeedManager.DefaultStepSize
        let stepDelay: TimeInterval = Double(speed.accelerationStepDelay ?? LocomotiveSpeedManager.DefaultStepDelay) / 1000.0

        let duration: TimeInterval = Double(steps) / Double(stepSize) * stepDelay
        return duration
    }

    /// Returns the distance, in cm, it takes for a locomotive to move at the specified speed for the specified duration.
    ///
    /// - Parameters:
    ///   - speedKph: the speed, in Kph
    ///   - duration: the duration, in seconds
    /// - Returns: the distance, in cm.
    static func distance(atSpeed speedKph: SpeedKph, forDuration duration: TimeInterval) -> DistanceCm {
        let distanceKm = Double(speedKph) * (duration / 3600.0)
        let distanceH0cm = (distanceKm * 1000 * 100) / 87.0
        return distanceH0cm
    }

    /// Returns the speed needed to move the specified distance with a specific duration.
    ///
    /// - Parameters:
    ///   - distanceInCm: the distance, in cm
    ///   - duration: the duration, in seconds
    /// - Returns: the speed, in Kph.
    static func speedToMove(distance: DistanceCm, forDuration: TimeInterval) -> SpeedKph {
        let durationInHour = forDuration / (60 * 60)

        // H0 is 1:87 (1cm in prototype = 0.0115cm in the layout)
        let modelDistanceKm = distance / 100_000
        let realDistanceKm = modelDistanceKm * 87
        let speedInKph = realDistanceKm / durationInHour

        let speed = SpeedKph(min(Double(UInt16.max), speedInKph))
        return speed
    }
}

extension Block {
    func maximumSpeedAllowed(speed: SpeedKph) -> SpeedKph {
        switch speedLimit {
        case .unlimited:
            return speed
        case .limited:
            return min(speed, LayoutFactory.DefaultLimitedSpeed)
        }
    }
}

extension Turnout {
    func maximumSpeedAllowed(speed: SpeedKph) -> SpeedKph {
        if let speedLimit = stateSpeedLimit[requestedState] {
            switch speedLimit {
            case .unlimited:
                return speed
            case .limited:
                return min(speed, LayoutFactory.DefaultLimitedSpeed)
            }
        } else {
            return speed
        }
    }
}
