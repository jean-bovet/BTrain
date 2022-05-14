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

/**
 This class handles the reservation of blocks for the train.

 There are two types of reserved blocks:
 - **Leading** Blocks: the blocks that are in front of the train (in the direction of travel). These blocks are reserved in order for the train to be able to move into them safely without risking a collision with another train..
 - **Occupied** Blocks: the blocks that are occupied by the train itself (locomotive and cars included). These blocks are usually behind the train in the opposite direction of travel,
 unless the locomotive is pushing the wagons, in which case they are in front of the locomotive.
 
 ````
                   Train (Locomotive + 2 cars)

                         ┌────┐  ┌────┐
                         │ C2 │  │ C1 │▶
                         └────┘  └────┘

┌───────┐  ┌───────┐  ╔═══════╗  ╔═══════╗  ┏━━━━━━━┓  ┏━━━━━━━┓
│  B5   │──│  B4   │──║  B3   ║──║  B2   ║──┃ | B1  ┃──┃  B0   ┃
└───────┘  └───────┘  ╚═══════╝  ╚═══════╝  ┗━━━━━━━┛  ┗━━━━━━━┛

     Free Blocks        Occupied Blocks        Heading Blocks



                   Train (Locomotive + 2 cars)

                         ┌────┐  ┌────┐
                         │ C2 │  │ C1 │◀
                         └────┘  └────┘

┏━━━━━━━┓  ┏━━━━━━━┓  ╔═══════╗  ╔═══════╗  ┌───────┐  ┌───────┐
┃  B5   ┃──┃  B4   ┃──║ B3 |  ║──║  B2   ║──│  B1   │──│  B0   │
┗━━━━━━━┛  ┗━━━━━━━┛  ╚═══════╝  ╚═══════╝  └───────┘  └───────┘

   Heading Blocks       Occupied Blocks       Free Blocks
 ````
*/
final class LayoutReservation {
    
    let layout: Layout
    let verbose: Bool
    
    // Internal structure used to hold information
    // about an upcoming turnout reservation
    internal struct TurnoutReservation {
        let turnout: Turnout
        let state: Turnout.State
        let sockets: Turnout.Reservation.Sockets
    }

    init(layout: Layout, verbose: Bool) {
        self.layout = layout
        self.verbose = verbose
   }
    
    // This function will try to reserve as many blocks as specified (maxNumberOfLeadingReservedBlocks)
    // in front of the train (leading blocks).
    // Note: it won't reserve blocks that are already reserved to avoid loops.
    func updateReservedBlocks(train: Train) throws -> Bool {
        // Remove the train from all the elements
        try freeElements(train: train)
        
        // Reserve and set the train and its wagon(s) using the necessary number of
        // elements (turnouts and blocks)
        try occupyBlockWith(train: train)

        // Reserve the number of leading blocks necessary
        return try reserveLeadingBlocks(train: train)
    }
    
    /// Removes the reservation for the leading blocks of the specified train but keep the occupied blocks intact (that the train actually occupies).
    ///
    /// - Parameter train: the train
    func removeLeadingBlocks(train: Train) throws {
        // Remove the train from all the elements
        try freeElements(train: train)
        
        // Reserve and set the train and its wagon(s) using the necessary number of
        // elements (turnouts and blocks)
        try occupyBlockWith(train: train)
    }
    
    private func reserveLeadingBlocks(train: Train) throws -> Bool {
        // The route must be defined and not be empty
        guard let route = layout.route(for: train.routeId, trainId: train.id), !route.steps.isEmpty else {
            debug("Cannot reserve leading blocks because route is empty")
            return false
        }

        // We are going to iterate over all the remaining steps of the route until we
        // either (1) reach the end of the route or (2) we have reserved enough blocks.
        let startReservationIndex = min(route.lastStepIndex, train.routeStepIndex)
        let stepsToReserve = route.steps[startReservationIndex...route.lastStepIndex]
        
        // First of all, resolve the route to discover all non-specified turnouts and blocks
        guard let resolvedSteps = try RouteResolver(layout: layout, train: train).resolve(steps: stepsToReserve) else {
            return false
        }
        assert(resolvedSteps.count >= stepsToReserve.count)
        
        return try reserveSteps(train: train, route: route, resolvedSteps: resolvedSteps)
    }
    
    private func reserveSteps(train: Train, route: Route, resolvedSteps: [ResolvedRouteItem]) throws -> Bool {
        // Variable keeping track of the number of leading blocks that have been reserved.
        // At least one block must have been reserved to consider this function successfull.
        // Note: blocks that are reserved for the train and its wagons do not count against that count.
        var numberOfLeadingBlocksReserved = 0

        // Remember the turnouts between two blocks. This is because we are going to reserve
        // the turnouts between two blocks only when we can guarantee that the destination block
        // can be indeed reserved - otherwise we end up with a bunch of turnouts that are reserved
        // but lead to a non-reserved block.
        var turnouts = [TurnoutReservation]()

        // Remember the transitions between two blocks. This is because we are going to reserve
        // the turnouts between two blocks only when we can guarantee that the destination block
        // can be indeed reserved - otherwise we end up with a bunch of turnouts that are reserved
        // but lead to a non-reserved block.
        var transitions = [ITransition]()
        
        // Remember the previous step so we can determine the transitions between two elements.
        var previousStep: ResolvedRouteItem?

        // Iterate over all the resolved steps
        for step in resolvedSteps {
            try rememberTransitions(from: previousStep, to: step, transitions: &transitions)

            switch step {
            case .block(let stepBlock):
                if try !reserveBlock(block: stepBlock.block, direction: stepBlock.direction, train: train, route: route, numberOfLeadingBlocksReserved: &numberOfLeadingBlocksReserved, turnouts: &turnouts, transitions: &transitions) {
                    return numberOfLeadingBlocksReserved > 0
                }
                
            case .turnout(let stepTurnout):
                if !rememberTurnoutToReserve(turnout: stepTurnout.turnout, train: train, step: stepTurnout, numberOfLeadingBlocksReserved: &numberOfLeadingBlocksReserved, turnouts: &turnouts) {
                    return numberOfLeadingBlocksReserved > 0
                }
            }
            
            // Stop once we have reached the maximum number of leading blocks to reserve
            if numberOfLeadingBlocksReserved >= train.maxNumberOfLeadingReservedBlocks {
                break
            }
            
            previousStep = step
        }
        
        return numberOfLeadingBlocksReserved > 0
    }
    
    private func reserveBlock(block: Block, direction: Direction, train: Train, route: Route, numberOfLeadingBlocksReserved: inout Int, turnouts: inout [TurnoutReservation], transitions: inout [ITransition]) throws -> Bool {
        if block.isOccupied(by: train.id) {
            // The block is already reserved and contains a portion of the train
            // Note: we are not incrementing `numberOfLeadingBlocksReserved` because
            // an occupied block does not count as a "leading" block; it is occupied because
            // the train (or portion of it) occupies it.
            debug("Block \(block.name) is already reserved (and occupied) for \(train.name), nothing more to do.")
        } else {
            guard block.canBeReserved(withTrain: train, direction: direction) else {
                return false
            }
            
            // Now that the block can be reserved, reserve all the turnouts leading to
            // that block, including setting the appropriate state to each turnout
            for tr in turnouts {
                try reserveTurnout(reservation: tr, train: train)
            }
            turnouts.removeAll()
            
            // Reserve all the transitions
            for transition in transitions {
                guard transition.reserved == nil || (transition.reserved == train.id && transition.train == train.id) else {
                    throw LayoutError.transitionAlreadyReserved(transition: transition)
                }
                debug("Reserving transition \(transition) for \(train)")
                transition.reserved = train.id
            }
            transitions.removeAll()
            
            // Now reserve the block
            let reservation = Reservation(trainId: train.id, direction: direction)
            block.reserved = reservation
            train.leading.append(block)
            numberOfLeadingBlocksReserved += 1
            debug("Reserving block \(block.name) for \(reservation)")
        }
        
        // Stop reserving as soon as a block that is going to
        // stop the train is detected. That way, the train stops
        // without reserving any block ahead and upon restarting,
        // it will reserve what it needs in front of it.
        guard !layout.hasTrainReachedStationOrDestination(route, train, block) else {
            return false
        }
        
        return true
    }
    
    private func reserveTurnout(reservation: TurnoutReservation, train: Train) throws {
        let turnout = reservation.turnout
        guard turnout.canBeReserved else {
            throw LayoutError.turnoutAlreadyReserved(turnout: turnout)
        }
        
        turnout.requestedState = reservation.state
        turnout.reserved = .init(train: train.id, sockets: reservation.sockets)
        train.leading.append(turnout)

        BTLogger.reservation.debug("\(train, privacy: .public): request state \(turnout.requestedState, privacy: .public) for turnout \(turnout.name, privacy: .public)")
        layout.executor.sendTurnoutState(turnout: turnout) {
            BTLogger.reservation.debug("\(train, privacy: .public): request state \(turnout.requestedState, privacy: .public) for turnout \(turnout.name, privacy: .public) [command executed]")
        }
    }
    
    private func rememberTurnoutToReserve(turnout: Turnout, train: Train, step: ResolvedRouteItemTurnout, numberOfLeadingBlocksReserved: inout Int, turnouts: inout [TurnoutReservation]) -> Bool {
        let fromSocketId = step.entrySocketId
        let toSocketId = step.exitSocketId
        let state = turnout.state(fromSocket: fromSocketId, toSocket: toSocketId)

        if turnout.isOccupied(by: train.id) {
            // The turnout is already reserved and contains a portion of the train
            debug("Turnout \(turnout.name) is already reserved (and occupied) for \(train.name)")
            
            // If the turnout state is not what we are expecting, this means it is a turnout that is occupied
            // by the wagons behind the train; we are basically looping back into ourself here so stop reserving.
            // This can happen when there is a small loop and the length of the train is such that the head of
            // the train tries to reserve a block occupied by the tail of the train.
            if turnout.requestedState != state {
                return false
            }
        } else {
            // If the turnout is not occupied, check if we can reserve it. If not,
            // we stop the reservation here because it does not make sense to continue.
            guard turnout.canBeReserved else {
                return false
            }
            
            // If the turnout can be reserved, remember it and it will actually be reserved
            // when the block that is leads to can also be reserved.
            turnouts.append(TurnoutReservation(turnout: turnout, state: state, sockets: Turnout.Reservation.Sockets(fromSocketId: fromSocketId, toSocketId: toSocketId)))
        }
        
        return true
    }
    
    private func rememberTransitions(from previousStep: ResolvedRouteItem?, to step: ResolvedRouteItem, transitions: inout [ITransition]) throws {
        guard let previousStep = previousStep else {
            return
        }
        let fromSocket = previousStep.exitSocket
        let toSocket = step.entrySocket
        let trs = try layout.transitions(from: fromSocket, to: toSocket)
        transitions.append(contentsOf: trs)
    }
        
    // This method reserves and occupies all the necessary blocks (and parts of the block) to fit
    // the specified train with all its length, taking into account the length of each block.
    func occupyBlockWith(train: Train) throws {
        let trainVisitor = TrainVisitor(layout: layout)
        let result = try trainVisitor.visit(train: train) { transition in
            guard transition.reserved == nil else {
                throw LayoutError.transitionAlreadyReserved(transition: transition)
            }
            transition.reserved = train.id
            transition.train = train.id
        } turnoutCallback: { turnoutInfo in
            let turnout = turnoutInfo.turnout
            
            guard turnout.reserved == nil else {
                throw LayoutError.turnoutAlreadyReserved(turnout: turnout)
            }
            turnout.reserved = .init(train: train.id, sockets: turnoutInfo.sockets)
            turnout.train = train.id
        } blockCallback: { block, attributes in
            guard block.reserved == nil || attributes.headBlock else {
                throw LayoutError.blockAlreadyReserved(block: block)
            }
            
            let trainInstance = TrainInstance(train.id, attributes.trainDirection)
            block.train = trainInstance
            
            for (index, position) in attributes.positions.enumerated() {
                if index == 0 {
                    trainInstance.parts[position] = attributes.headBlock ? .locomotive : .wagon
                } else {
                    trainInstance.parts[position] = .wagon
                }
            }
            
            block.reserved = .init(trainId: train.id, direction: attributes.trainDirection)
            train.occupiedBlocks.append(block)
        }
        if !result {
            throw LayoutError.cannotReserveAllElements(train: train)
        }
    }
        
    // This methods frees all the reserved elements except the block in which the locomotive is located
    func freeElements(train: Train) throws {
        train.leading.clear()
        train.occupiedBlocks.removeAll()

        layout.blockMap.values
            .filter { $0.reserved?.trainId == train.id }
            .forEach { block in
                // Only free a block if the block is not the one the train is located on or
                if block.id != train.blockId {
                    block.reserved = nil
                    block.train = nil
                }
            }
        layout.turnouts.filter { $0.reserved?.train == train.id }.forEach { $0.reserved = nil; $0.train = nil }
        layout.transitions.filter { $0.reserved == train.id }.forEach { $0.reserved = nil; $0.train = nil }
    }
    
    /// This method returns the maximum speed allowed by all the elements occupied by
    /// the specified train, which includes blocks and turnouts.
    func maximumSpeedAllowed(train: Train, route: Route?) -> TrainSpeed.UnitKph {
        var maximumSpeedAllowed: TrainSpeed.UnitKph = LayoutFactory.DefaultMaximumSpeed
        
        layout.blocks.filter({ $0.reserved?.trainId == train.id }).forEach { block in
            switch block.speedLimit {
            case .unlimited:
                break
            case .limited:
                maximumSpeedAllowed = min(maximumSpeedAllowed, LayoutFactory.DefaultLimitedSpeed)
            }
        }
        
        layout.turnouts.filter { $0.reserved?.train == train.id }.forEach { turnout in
            if let speedLimit = turnout.stateSpeedLimit[turnout.requestedState] {
                switch speedLimit {
                case .unlimited:
                    break
                case .limited:
                    maximumSpeedAllowed = min(maximumSpeedAllowed, LayoutFactory.DefaultLimitedSpeed)
                }
            }
        }
                        
        // If there is a leading reserved block where the train needs to stop,
        // make sure the speed is limited, otherwise the train will likely overshoot
        // the block in which it must stop.
        for block in train.leading.blocks {
            if layout.hasTrainReachedStationOrDestination(route, train, block) {
                maximumSpeedAllowed = min(maximumSpeedAllowed, LayoutFactory.DefaultLimitedSpeed)
                break
            }
        }

        // Limit the speed if the train is one block away from the destination block
        if let route = layout.route(for: train.routeId, trainId: train.id), route.steps.count > 0, train.routeStepIndex >= route.lastStepIndex - 1 {
            maximumSpeedAllowed = min(maximumSpeedAllowed, LayoutFactory.DefaultLimitedSpeed)
        }
        
        // Check if the current maximum speed is allowed
        if !isBrakingDistanceRespected(train: train, speed: maximumSpeedAllowed) {
            // If not, check if the default limited speed is allowed
            maximumSpeedAllowed = min(maximumSpeedAllowed, LayoutFactory.DefaultLimitedSpeed)
            if !isBrakingDistanceRespected(train: train, speed: maximumSpeedAllowed) {
                // If not, the braking speed is used
                maximumSpeedAllowed = min(maximumSpeedAllowed, LayoutFactory.DefaultBrakingSpeed)
            }
        }

        BTLogger.router.debug("\(train, privacy: .public): maximum allowed speed is \(maximumSpeedAllowed)kph")
        
        return maximumSpeedAllowed
    }
    
    /// Returns true if the train can stop within the available lead distance at the specified speed.
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
        let leadingDistance = train.leading.distance
        
        // Compute the distance necessary to bring the train to a full stop
        let steps = train.speed.steps(for: speed).value
        let brakingStepSize = train.speed.accelerationStepSize ?? TrainControllerAcceleration.DefaultStepSize
        let brakingStepDelay = Double(train.speed.accelerationStepDelay ?? TrainControllerAcceleration.DefaultStepDelay) / 1000.0
        
        let brakingDelaySeconds = Double(steps) / Double(brakingStepSize) * Double(brakingStepDelay) + train.speed.stopSettleDelay
        
        let speedKph = Double(speed)
        let brakingDistanceKm = speedKph * (brakingDelaySeconds / 3600.0)
        let brakingDistanceH0cm = (brakingDistanceKm * 1000*100) / 87.0
                            
        // The braking distance is respected if it is shorter or equal
        // to the leading distance available.
        let respected = brakingDistanceH0cm <= leadingDistance
        if respected {
            BTLogger.router.debug("\(train, privacy: .public): can come to a fullstop in \(brakingDistanceH0cm, format: .fixed(precision: 1))cm (in \(brakingDelaySeconds, format: .fixed(precision: 1))s) at \(speedKph, format: .fixed(precision: 1))kph. The leading distance is \(leadingDistance, format: .fixed(precision: 1))cm with blocks \(train.leading.blocks, privacy: .public)")
        } else {
            BTLogger.router.debug("\(train, privacy: .public): ⚠️ cannot come to a fullstop in \(brakingDistanceH0cm, format: .fixed(precision: 1))cm (in \(brakingDelaySeconds, format: .fixed(precision: 1))s) at \(speedKph, format: .fixed(precision: 1))kph because the leading distance is \(leadingDistance, format: .fixed(precision: 1))cm with blocks \(train.leading.blocks, privacy: .public)")
        }
        return respected
    }
    
    private func debug(_ msg: String) {
        if verbose {
            BTLogger.debug(msg)
        }
    }

}
