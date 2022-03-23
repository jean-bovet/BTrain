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

// This class handles the occupied and leading blocks reservation for a specified train.
// - A occupied block is a block, either behind or in front of the locomotive, that contains the wagons of the train.
//   Note that if a locomotive pushes the wagon, the occupied blocks are actually "in front" of the train.
// - A leading block is a block in front of the train that is reserved in order for the train to be
//   able to move into it safely without risking a collision with another train.
final class LayoutReservation {
    
    let layout: Layout
    let resolver: RouteResolver
    let visitor: ElementVisitor

    // Internal structure used to hold information
    // about an upcoming turnout reservation
    internal struct TurnoutReservation {
        let turnout: Turnout
        let state: Turnout.State
        let sockets: Turnout.Reservation.Sockets
    }

    init(layout: Layout) {
        self.layout = layout
        self.resolver = RouteResolver(layout: layout)
        self.visitor = ElementVisitor(layout: layout)
   }
    
    // This function will try to reserve as many blocks as specified (maxNumberOfLeadingReservedBlocks)
    // in front of the train (leading blocks).
    // Note: it won't reserve blocks that are already reserved to avoid loops.
    @discardableResult
    func updateReservedBlocks(train: Train, trainStarting: Bool = false) throws -> Bool {
        // Remove the train from all the elements
        try freeElements(train: train)
        
        // Reserve and set the train and its wagon(s) using the necessary number of
        // elements (turnouts and blocks)
        try fillBlocks(train: train)

        // Reserve the number of leading blocks necessary
        return try reserveLeadingBlocks(train: train, trainStarting: trainStarting)
    }

    private func reserveLeadingBlocks(train: Train, trainStarting: Bool) throws -> Bool {
        // The train must be running (or we have the specific force flag which happens when the train starts)
        guard train.state == .running || trainStarting else {
            return false
        }
        
        // The route must be defined and not be empty
        guard let route = layout.route(for: train.routeId, trainId: train.id), !route.steps.isEmpty else {
            return false
        }

        // We are going to iterate over all the remaining steps of the route until we
        // either (1) reach the end of the route or (2)) we have reserved enough blocks.
        let startReservationIndex = min(route.lastStepIndex, train.routeStepIndex)
        let stepsToReserve = route.steps[startReservationIndex...route.lastStepIndex]
        
        // First of all, resolve the route to discover all non-specified turnouts and blocks
        guard let resolvedSteps = try resolver.resolve(steps: stepsToReserve, trainId: train.id) else {
            return false
        }
        assert(resolvedSteps.count >= stepsToReserve.count)

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
        var previousStep: Route.Step?

        // Iterate over all the resolved steps
        for step in resolvedSteps {
            try rememberTransitions(from: previousStep, to: step, transitions: &transitions)

            if let blockId = step.blockId {
                guard let block = layout.block(for: blockId) else {
                    throw LayoutError.blockNotFound(blockId: blockId)
                }
                                
                guard let direction = step.direction else {
                    throw LayoutError.missingDirection(step: step)
                }

                if try !reserveBlock(block: block, direction: direction, train: train, numberOfLeadingBlocksReserved: &numberOfLeadingBlocksReserved, turnouts: &turnouts, transitions: &transitions) {
                    return numberOfLeadingBlocksReserved > 0
                }
            } else if let turnoutId = step.turnoutId {
                guard let turnout = layout.turnout(for: turnoutId) else {
                    throw LayoutError.turnoutNotFound(turnoutId: turnoutId)
                }
                
                if try !rememberTurnoutToReserve(turnout: turnout, train: train, step: step, numberOfLeadingBlocksReserved: &numberOfLeadingBlocksReserved, turnouts: &turnouts) {
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
    
    private func reserveBlock(block: Block, direction: Direction, train: Train, numberOfLeadingBlocksReserved: inout Int, turnouts: inout [TurnoutReservation], transitions: inout [ITransition]) throws -> Bool {
        if block.isOccupied(by: train.id) {
            // The block is already reserved and contains a portion of the train
            // Note: we are not incrementing `numberOfLeadingBlocksReserved` because
            // an occupied block does not count as a "leading" block; it is occupied because
            // the train (or portion of it) occupies it.
            BTLogger.debug("Already occupied (and reserved) \(block.name) for \(train.name)")
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
                BTLogger.debug("Reserved transition \(transition) for \(train)")
                transition.reserved = train.id
            }
            transitions.removeAll()
            
            // Now reserve the block
            let reservation = Reservation(trainId: train.id, direction: direction)
            block.reserved = reservation
            numberOfLeadingBlocksReserved += 1
            BTLogger.debug("Reserved block \(block.name) for \(reservation)")
        }
        
        // Stop reserving as soon as a block that is going to
        // stop the train is detected. That way, the train stops
        // without reserving any block ahead and upon restarting,
        // it will reserve what it needs in front of it.
        guard !layout.trainShouldStop(train: train, block: block) else {
            return false
        }
        
        return true
    }
    
    private func reserveTurnout(reservation: TurnoutReservation, train: Train) throws {
        let turnout = reservation.turnout
        guard turnout.canBeReserved else {
            throw LayoutError.turnoutAlreadyReserved(turnout: turnout)
        }
        
        turnout.state = reservation.state
        turnout.reserved = .init(train: train.id, sockets: reservation.sockets)
        
        layout.executor.sendTurnoutState(turnout: turnout) { }
        BTLogger.debug("Reserved turnout \(turnout.name) for \(train) and state \(turnout.state)")
    }
    
    private func rememberTurnoutToReserve(turnout: Turnout, train: Train, step: Route.Step, numberOfLeadingBlocksReserved: inout Int, turnouts: inout [TurnoutReservation]) throws -> Bool {
        let fromSocketId = try step.entrySocketId()
        let toSocketId = try step.exitSocketId()
        let state = turnout.state(fromSocket: fromSocketId, toSocket: toSocketId)

        if turnout.isOccupied(by: train.id) {
            // The turnout is already reserved and contains a portion of the train
            BTLogger.debug("Already occupied (and reserved) \(turnout.name) for \(train.name)")
            
            // If the turnout state is not what we are expecting, this means it is a turnout that is occupied
            // by the wagons behind the train; we are basically looping back into ourself here so stop reserving.
            // This can happen when there is a small loop and the length of the train is such that the head of
            // the train tries to reserve a block occupied by the tail of the train.
            if turnout.state != state {
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
    
    private func rememberTransitions(from previousStep: Route.Step?, to step: Route.Step, transitions: inout [ITransition]) throws {
        guard let previousStep = previousStep else {
            return
        }
        let fromSocket = try previousStep.exitSocketOrThrow()
        let toSocket = try step.entrySocketOrThrow()
        let trs = try layout.transitions(from: fromSocket, to: toSocket)
        transitions.append(contentsOf: trs)
    }
    
    // This method reserves and occupies all the necessary blocks (and parts of the block) to fit
    // the specified train with all its length, taking into account the length of each block.
    func fillBlocks(train: Train) throws {
        guard let fromBlockId = train.blockId else {
            throw LayoutError.trainNotAssignedToABlock(train: train)
        }
        
        guard let fromBlock = layout.block(for: fromBlockId) else {
            throw LayoutError.blockNotFound(blockId: fromBlockId)
        }
                        
        // First, free all the reserved block "behind" the train so we can reserve them again
        // using the length of the train in consideraion
        try freeReservedElements(fromBlockId: fromBlockId,
                                 direction: fromBlock.wagonDirection(for: train),
                                 trainId: train.id)
        
        // Fill all the elements that are occupied by the train
        try fillElementWith(train: train)
    }
    
    private func fillElementWith(train: Train) throws {
        let trainVisitor = TrainVisitor(layout: layout)
        try trainVisitor.visit(train: train) { transition in
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
        }
    }

    private func freeReservedElements(fromBlockId: Identifier<Block>, direction: Direction, trainId: Identifier<Train>) throws {
        try visitor.visit(fromBlockId: fromBlockId, direction: direction) { info in
            if let transition = info.transition {
                if transition.reserved == trainId {
                    transition.reserved = nil
                    transition.train = nil
                } else {
                    return .stop
                }
            } else if let turnout = info.turnout?.turnout {
                if turnout.reserved?.train == trainId {
                    turnout.reserved = nil
                    turnout.train = nil
                } else {
                    return .stop
                }
            } else if let blockInfo = info.block, blockInfo.block.id != fromBlockId {
                if blockInfo.block.reserved?.trainId == trainId {
                    blockInfo.block.reserved = nil
                    blockInfo.block.train = nil
                } else {
                    return .stop
                }
            }
            
            return .continue
        }
    }
    
    // This methods frees all the reserved elements except the block in which the locomotive is located
    private func freeElements(train: Train) throws {
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
    
    // This methods frees all the reserved elements except the block in which the locomotive is located
    // This method returns the maximum speed allowed by all the elements occupied by
    // the specified train, which includes blocks and turnouts.
    func maximumSpeedAllowed(train: Train) -> TrainSpeed.UnitKph {
        var maximumSpeedAllowed: TrainSpeed.UnitKph = LayoutFactory.DefaultMaximumSpeed
//        layout.blockMap.values
//            .filter { $0.reserved?.trainId == train.id }
//            .forEach { block in
//                // TODO: block speed limit
//            }
        layout.turnouts.filter { $0.reserved?.train == train.id }.forEach { turnout in
            if let speedLimit = turnout.stateSpeedLimited[turnout.state] {
                switch speedLimit {
                case .unlimited:
                    break
                case .limited:
                    maximumSpeedAllowed = min(maximumSpeedAllowed, LayoutFactory.DefaultLimitedSpeed)
                }
            }
        }
        
        return maximumSpeedAllowed
    }

}
