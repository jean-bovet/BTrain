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
    /// in the current block, at the specified speed.
    ///
    /// The leading distance is the distance of all the reserved leading blocks in front of the train.
    /// The goal is to ensure that a train can stop safely at any moment with the leading distance
    /// available - otherwise, it might overshoot the leading blocks in case a stop is requested.
    ///
    /// - Parameters:
    ///   - train: the train
    ///   - speed: the speed to evaluate
    /// - Returns: true if the train can stop with the available leading distance, false otherwise
    func isBrakingDistanceRespected(train: Train, speed: TrainSpeed.UnitKph) -> Bool {
        let distanceLeftInBlock = distanceLeftInCurrentBlock(train: train)
        let leadingDistance = distanceLeftInBlock + train.leading.settledDistance
        
        // Compute the distance necessary to bring the train to a full stop
        let result = distanceNeededToChangeSpeed(ofTrain: train, from: speed, to: 0)
        
        // The braking distance is respected if it is shorter or equal to the leading distance available.
        let respected = result.distance <= leadingDistance
        if respected {
            BTLogger.router.debug("\(train, privacy: .public): can come to a full stop in \(result.distance, format: .fixed(precision: 1))cm (in \(result.duration, format: .fixed(precision: 1))s) at \(Double(speed), format: .fixed(precision: 1))kph. The leading distance is \(leadingDistance, format: .fixed(precision: 1))cm with blocks \(train.leading.blocks, privacy: .public)")
        } else {
            BTLogger.router.debug("\(train, privacy: .public): ⚠️ cannot come to a full stop in \(result.distance, format: .fixed(precision: 1))cm (in \(result.duration, format: .fixed(precision: 1))s) at \(Double(speed), format: .fixed(precision: 1))kph because the leading distance is \(leadingDistance, format: .fixed(precision: 1))cm with blocks \(train.leading.blocks, privacy: .public)")
        }
        return respected
    }
    
    /// Returns the maximum speed allowed for the train, given the occupied and leading items.
    ///
    /// The following rules are applied:
    /// - Restricted speed limit on occupied items (blocks or turnouts) are applied immediately.
    /// - The settled lead distance is used to compute the speed to safely brake in the available distance.
    /// - The lead distance to the first restricted lead item (for example, a turnout) is used to compute the speed to safely brake.
    ///
    /// - Parameter train: the train
    /// - Returns: the maximum allowed speed
    func maximumSpeedAllowed(train: Train) -> TrainSpeed.UnitKph {
        var maximumSpeedAllowed = LayoutFactory.DefaultMaximumSpeed

        maximumSpeedAllowed = min(maximumSpeedAllowed, occupiedBlocksMaximumSpeed(train: train))
        maximumSpeedAllowed = min(maximumSpeedAllowed, unrestrictedLeadMaximumSpeed(train: train))
        maximumSpeedAllowed = min(maximumSpeedAllowed, settledLeadMaximumSpeed(train: train))

        BTLogger.router.debug("\(train, privacy: .public): maximum allowed speed is \(maximumSpeedAllowed)kph")
        
        return maximumSpeedAllowed
    }
    
    /// Returns the maximum speed allowed in the blocks (and turnouts) occupied by the train.
    /// This takes into account speed limits for turnout branches and more.
    /// - Parameter train: the train
    /// - Returns: the maximum allowed speed
    private func occupiedBlocksMaximumSpeed(train: Train) -> TrainSpeed.UnitKph {
        var maximumSpeedAllowed: TrainSpeed.UnitKph = LayoutFactory.DefaultMaximumSpeed
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
    /// - Parameter train: the train
    /// - Returns: the maximum speed
    private func unrestrictedLeadMaximumSpeed(train: Train) -> TrainSpeed.UnitKph {
        let distanceLeftInBlock = distanceLeftInCurrentBlock(train: train)
        var unrestrictedLeadingDistance = distanceLeftInBlock
        var speed = LayoutFactory.DefaultMaximumSpeed
        for item in train.leading.items {
            let distance: Double
            switch item {
            case .block(let block):
                speed = block.maximumSpeedAllowed(speed: speed)
                distance = block.length ?? 0

            case .turnout(let turnout):
                speed = turnout.maximumSpeedAllowed(speed: speed)
                distance = turnout.length ?? 0
            }
            
            if speed < LayoutFactory.DefaultMaximumSpeed {
                // We stop as soon as a speed restriction is found.
                // The distance we have accumulated so far is going to
                // be used below to compute the maximum speed.
                return maximumSpeedToBrake(train: train, toSpeed: speed, withDistance: unrestrictedLeadingDistance)
            } else {
                unrestrictedLeadingDistance += distance
            }
        }

        return speed
    }
    
    /// Returns the maximum speed allowed to safely change the speed of the train to the specified target speed given the distance available.
    /// - Parameters:
    ///   - train: the train
    ///   - speed: the desired target speed
    ///   - distance: the distance available to change the train speed
    /// - Returns: the maximum speed to brake within the distance
    private func maximumSpeedToBrake(train: Train, toSpeed speed: TrainSpeed.UnitKph, withDistance distance: Double) -> TrainSpeed.UnitKph {
        var brakingDistance = distanceNeededToChangeSpeed(ofTrain: train, from: LayoutFactory.DefaultMaximumSpeed, to: speed)
        guard brakingDistance.distance > distance else {
            return LayoutFactory.DefaultMaximumSpeed
        }
        
        brakingDistance = distanceNeededToChangeSpeed(ofTrain: train, from: LayoutFactory.DefaultLimitedSpeed, to: speed)
        guard brakingDistance.distance > distance else {
            return LayoutFactory.DefaultLimitedSpeed
        }

        brakingDistance = distanceNeededToChangeSpeed(ofTrain: train, from: LayoutFactory.DefaultBrakingSpeed, to: speed)
        guard brakingDistance.distance > distance else {
            return LayoutFactory.DefaultBrakingSpeed
        }

        return 0
    }
    
    /// Returns the maximum speed allowed by the available lead settled distance, including the distance left
    /// in the current block.
    ///
    /// - Parameter train: the train
    /// - Returns: the maximum speed
    private func settledLeadMaximumSpeed(train: Train) -> TrainSpeed.UnitKph {
        let distanceLeftInBlock = distanceLeftInCurrentBlock(train: train)
        let settledDistance = distanceLeftInBlock + train.leading.settledDistance
        return maximumSpeedToBrake(train: train, toSpeed: 0, withDistance: settledDistance)
    }
    
    /// Returns the distance left in the current block
    /// - Parameter train: the train
    /// - Returns: the distance left
    private func distanceLeftInCurrentBlock(train: Train) -> Double {
        guard let currentBlock = layout.currentBlock(train: train) else {
            return 0
        }
        guard let distanceLeftInBlock = currentBlock.distanceLeftInBlock(train: train) else {
            return 0
        }

        return distanceLeftInBlock
    }
    
    struct DistanceChangeResult {
        let distance: Double
        let duration: TimeInterval
    }
    
    /// Returns the distance needed to change the speed from one speed to another
    /// - Parameters:
    ///   - train: the train
    ///   - speed1: the original speed
    ///   - speed2: the desired speed
    /// - Returns: the distance
    private func distanceNeededToChangeSpeed(ofTrain train: Train, from speed1:TrainSpeed.UnitKph, to speed2: TrainSpeed.UnitKph) -> DistanceChangeResult {
        let steps1 = train.speed.steps(for: speed1).value
        let steps2 = train.speed.steps(for: speed2).value
        let steps = steps1 - steps2
        
        guard steps != 0 else {
            return DistanceChangeResult(distance: 0, duration: 0)
        }

        let brakingStepSize = train.speed.accelerationStepSize ?? TrainSpeedManager.DefaultStepSize
        let brakingStepDelay = Double(train.speed.accelerationStepDelay ?? TrainSpeedManager.DefaultStepDelay) / 1000.0
        
        let brakingDelaySeconds = Double(steps) / Double(brakingStepSize) * Double(brakingStepDelay) + train.speed.stopSettleDelay
        
        let speedKph = Double(speed1)
        let brakingDistanceKm = speedKph * (brakingDelaySeconds / 3600.0)
        let brakingDistanceH0cm = (brakingDistanceKm * 1000*100) / 87.0

        return DistanceChangeResult(distance: brakingDistanceH0cm, duration: brakingDelaySeconds)
    }
    
}

extension Block {
    func maximumSpeedAllowed(speed: TrainSpeed.UnitKph) -> TrainSpeed.UnitKph {
        switch speedLimit {
        case .unlimited:
            return speed
        case .limited:
            return min(speed, LayoutFactory.DefaultLimitedSpeed)
        }
    }
}

extension Turnout {
    func maximumSpeedAllowed(speed: TrainSpeed.UnitKph) -> TrainSpeed.UnitKph {
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
