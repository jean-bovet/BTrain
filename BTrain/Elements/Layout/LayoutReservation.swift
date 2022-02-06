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

// TODO: use the word "occupied" block instead of "trailing" so the notion of direction is dropped
// This class handles the trailing and leading blocks reservation for a specified train.
// - A trailing block is a block behind the train that contains the wagons of the train.
//   Note that if a locomotive pushes the wagon, the trailing blocks are actually "in front" of the train.
// - A leading block is a block in front of the train that is reserved in order for the train to be
//   able to move into it safely without risking a collision with another train.
final class LayoutReservation {
    
    let layout: Layout
    let resolver: RouteResolver
    let visitor: ElementVisitor

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
        // Before trying to reserve the leading blocks, let's free up
        // all the reserved elements (turnouts, transitions, blocks) in front
        // of the train. This is to keep the algorithm simple:
        // (1) Free up leading reserved blocks
        // (2) Reserve leading reserved blocks
        try freeElements(train: train)
        
        // Make sure to fill the blocks with the train, taking into account its length.
        // Note: this is necessary because if the train is "pushed" by the locomotive,
        // the leading blocks will be freedup and need to be reserved again for the train.
        try fillBlocks(train: train)
        
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
        let resolvedSteps = try resolver.resolve(steps: stepsToReserve, trainId: train.id)
        assert(resolvedSteps.count >= stepsToReserve.count)

        // Variable keeping track of the number of leading blocks that have been reserved.
        // At least one block must have been reserved to consider this function successfull.
        // Note: blocks that are reserved for the train and its wagons do not count against that count.
        var numberOfLeadingBlocksReserved = 0

        // Remember the turnouts between two blocks. This is because we are going to reserve
        // the turnouts between two blocks only when we can guarantee that the destination block
        // can be indeed reserved - otherwise we end up with a bunch of turnouts that are reserved
        // but lead to a non-reserved block.
        var turnouts = [(Turnout, Turnout.State)]()

        var transitions = [ITransition]()
        
        var previousStep: Route.Step?

        // Iterate over all the resolved steps
        for step in resolvedSteps {
            try rememberTransitions(from: previousStep, to: step, transitions: &transitions)

            if let blockId = step.blockId {
                guard let block = layout.block(for: blockId) else {
                    throw LayoutError.blockNotFound(blockId: blockId)
                }
                                
                guard let direction = step.direction else {
                    // TODO: throw
                    fatalError()
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
    
    private func reserveBlock(block: Block, direction: Direction, train: Train, numberOfLeadingBlocksReserved: inout Int, turnouts: inout [(Turnout, Turnout.State)], transitions: inout [ITransition]) throws -> Bool {
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
            for (turnout, state) in turnouts {
                try reserveTurnout(turnout: turnout, state: state, train: train)
            }
            turnouts.removeAll()
            
            // Reserve all the transitions
            for transition in transitions {
                guard transition.reserved == nil || (transition.reserved == train.id && transition.train == train.id) else {
                    // TODO: exception
                    fatalError()
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
    
    private func reserveTurnout(turnout: Turnout, state: Turnout.State, train: Train) throws {
        guard turnout.canBeReserved else {
            // TODO: exception
            // Should not happen. Or maybe if the turnout loops on themselves which would be weird.
            fatalError()
        }
        
        turnout.state = state
        turnout.reserved = train.id
        layout.executor?.sendTurnoutState(turnout: turnout) { }
        BTLogger.debug("Reserved turnout \(turnout.name) for \(train) and state \(state)")
    }
    
    private func rememberTurnoutToReserve(turnout: Turnout, train: Train, step: Route.Step, numberOfLeadingBlocksReserved: inout Int, turnouts: inout [(Turnout, Turnout.State)]) throws -> Bool {
        guard let entrySocket = step.entrySocket else {
            // TODO: exception
            fatalError()
        }
        
        guard let fromSocket = entrySocket.socketId else {
            throw LayoutError.socketIdNotFound(socket: entrySocket)
        }

        guard let exitSocket = step.exitSocket else {
            // TODO: exception
            fatalError()
        }

        guard let toSocket = exitSocket.socketId else {
            throw LayoutError.socketIdNotFound(socket: exitSocket)
        }

        let state = turnout.state(fromSocket: fromSocket, toSocket: toSocket)

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
            turnouts.append((turnout, state))
        }
        
        return true
    }
    
    private func rememberTransitions(from previousStep: Route.Step?, to step: Route.Step, transitions: inout [ITransition]) throws {
        guard let previousStep = previousStep else {
            return
        }

        guard let exitSocket = previousStep.exitSocket else {
            // TODO: throw
            fatalError()
        }
        guard let entrySocket = step.entrySocket else {
            // TODO: throw
            fatalError()
        }
        
        let trs = try layout.transitions(from: exitSocket, to: entrySocket)
        print("** \(exitSocket) >>> \(entrySocket) : \(trs.count)")
        transitions.append(contentsOf: trs)
    }
    
    // This method reserves and occupies all the necessary blocks (and parts of the block) to fit
    // the specified train with all its length, taking into account the length of each block.
    func fillBlocks(train: Train) throws {
        guard let fromBlockId = train.blockId else {
            throw LayoutError.trainNotAssignedToABlock(trainId: train.id)
        }
        
        guard let fromBlock = layout.block(for: fromBlockId) else {
            throw LayoutError.blockNotFound(blockId: fromBlockId)
        }
        
        guard let trainInstance = fromBlock.train else {
            throw LayoutError.trainNotFoundInBlock(blockId: fromBlockId)
        }
        
        guard let trainLength = train.length else {
            return
        }
        
        // Gather the train direction of travel within the current block
        // and the wagon direction - which can be the same or the opposite.
        // For example:
        //              ▷             ◁             ◁
        //         ┌─────────┐   ┌─────────┐   ┌─────────┐
        //         │ ■■■■■■▶ │──▶│ ■■■■■■▶ │──▶│ ■■■■■■▶ │
        //         └─────────┘   └─────────┘   └─────────┘
        //  Train:   next          previous      previous
        //  Wagon:   previous      next          next
        //  trainAndWagonDirectionIdentical = false
        //              ▷             ◁             ◁
        //         ┌─────────┐   ┌─────────┐   ┌─────────┐
        //         │ ▶■■■■■■ │──▶│ ▶■■■■■■ │──▶│ ▶■■■■■■ │
        //         └─────────┘   └─────────┘   └─────────┘
        //  Train:   next          previous      previous
        //  Wagon:   next          previous      previous
        //  trainAndWagonDirectionIdentical = true
        //
        // Direction of travel of the train within the block
        let trainDirection = trainInstance.direction
        // Direction in which the wagon are layout from the locomotive
        let wagonDirection = train.wagonsPushedByLocomotive ? trainDirection : trainDirection.opposite
        
        // First, free all the reserved block "behind" the train so we can reserve them again
        // using the length of the train in consideraion
        try freeReservedElements(fromBlockId: fromBlockId, direction: wagonDirection, trainId: train.id)

        // Keep track of the remaining train length that needs to have reserved blocks
        var remainingTrainLength = trainLength

        try visitor.visit(fromBlockId: fromBlock.id, direction: wagonDirection, callback: { info in
            if let transition = info.transition {
                // Transition is just a virtual connection between two elements, no physical length exists.
                guard transition.reserved == nil else {
                    throw LayoutError.transitionAlreadyReserved(transition: transition)
                }
                transition.reserved = train.id
                transition.train = train.id
            } else if let turnout = info.turnout {
                guard turnout.reserved == nil else {
                    throw LayoutError.turnoutAlreadyReserved(turnout: turnout)
                }
                if let length = turnout.length {
                    remainingTrainLength -= length
                }
                turnout.reserved = train.id
                turnout.train = train.id
            } else if let block = info.block, let wagonDirection = info.direction {
                guard block.reserved == nil || info.index == 0 else {
                    throw LayoutError.blockAlreadyReserved(block: block)
                }
                
                if block.length == nil {
                    // TODO: throw appropriate exception
                    return .stop
                }
                
                // Determine the direction of the train within the current block by using
                // the flag indicating if the wagons are pushed or not by the locomotive.
                let trainDirection = train.wagonsPushedByLocomotive ? wagonDirection : wagonDirection.opposite
                remainingTrainLength = reserveBlockParts(train: train,
                                                         remainingTrainLength: remainingTrainLength,
                                                         block: block,
                                                         headBlock: info.index == 0,
                                                         wagonDirection: wagonDirection,
                                                         trainDirection: trainDirection)
                block.reserved = .init(trainId: train.id, direction: trainDirection)
            }

            if remainingTrainLength > 0 {
                return .continue
            } else {
                return .stop
            }
        })
    }
    
    private func reserveBlockParts(train: Train, remainingTrainLength: Double, block: Block, headBlock: Bool, wagonDirection: Direction, trainDirection: Direction) -> Double {
        let trainInstance = TrainInstance(train.id, trainDirection)
        trainInstance.parts.removeAll()
        
        var currentRemainingTrainLength = remainingTrainLength
        
        // [ 0 | 1 | 2 ]
        //   =   =>
        //   <   <   <   (direction previous)
        //      <=   =
        //   >   >   >   (direction next)
                
        // Determine the starting position where to begin filling out parts of the block
        var position: Int
        if headBlock {
            position = train.position
        } else {
            position = wagonDirection == .previous ? block.feedbacks.count : 0
        }
        
        let increment = wagonDirection == .previous ? -1 : 1

        // Gather all the part length to ensure they are all defined.
        if let allPartsLength = block.allPartsLength() {
            if headBlock {
                trainInstance.parts[position] = .locomotive
                // Don't take into consideration the length of that part
                // because the locomotive could be at the beginning of the part.
                // This will get more precise once we manage the distance
                // using the real speed conversion.
            } else {
                trainInstance.parts[position] = .wagon
                currentRemainingTrainLength -= allPartsLength[position]!
            }
            
            position += increment
            while ((increment < 0 && position >= 0) || (increment > 0 && position < block.feedbacks.count + 1)) && currentRemainingTrainLength > 0 {
                trainInstance.parts[position] = .wagon
                currentRemainingTrainLength -= allPartsLength[position]!

                position += increment
            }
        } else if let length = block.length {
            // If the parts length are not available, let's use the block full length
            trainInstance.parts[position] = headBlock ? .locomotive : .wagon

            position += increment
            while ((increment < 0 && position >= 0) || (increment > 0 && position < block.feedbacks.count + 1)) {
                trainInstance.parts[position] = .wagon
                position += increment
            }

            currentRemainingTrainLength -= length
        }
        
        block.train = trainInstance
        
        return currentRemainingTrainLength
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
            } else if let turnout = info.turnout {
                if turnout.reserved == trainId {
                    turnout.reserved = nil
                    turnout.train = nil
                } else {
                    return .stop
                }
            } else if let block = info.block, block.id != fromBlockId {
                if block.reserved?.trainId == trainId {
                    block.reserved = nil
                    block.train = nil
                } else {
                    return .stop
                }
            }
            
            return .continue
        }
    }
    
    // This method will free all the leading blocks reserved for the specified train and
    // update the trailing blocks that the train occupies with its length.
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
        layout.turnouts.filter { $0.reserved == train.id }.forEach { $0.reserved = nil; $0.train = nil }
        layout.transitions.filter { $0.reserved == train.id }.forEach { $0.reserved = nil; $0.train = nil }
    }
    
}
