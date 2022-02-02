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

extension Layout {
    
    // This function will try to reserve as many blocks as specified (maxNumberOfLeadingReservedBlocks)
    // in front of the train (leading blocks).
    // Note: it won't reserve blocks that are already reserved to avoid loops.
    @discardableResult
    func updateReservedBlocks(train: Train, forceReserveLeadingBlocks: Bool = false) throws -> Bool {
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
        
        return try reserveLeadingBlocks(train: train, forceReserveLeadingBlocks: forceReserveLeadingBlocks)
    }
    
    private func reserveLeadingBlocks(train: Train, forceReserveLeadingBlocks: Bool) throws -> Bool {
        // Reserve the leading blocks only when a route is defined and when the train is running.
        guard train.state == .running || forceReserveLeadingBlocks else {
            return false
        }
        
        guard let route = self.route(for: train.routeId, trainId: train.id) else {
            return false
        }
        
        guard route.steps.count > 0 else {
            return false
        }

        // We are going to iterate over all the remaining steps of the route until we
        // either (1) reach the end of the route or (2)) we have reserved enough blocks.
        let startReservationIndex = min(route.lastStepIndex, train.routeStepIndex + 1)
        let stepsToReserve = route.steps[startReservationIndex...route.lastStepIndex]

        // Remember the last step so we can reserve all the transitions and turnouts
        var previousStep = route.steps[train.routeStepIndex]

        // Variable keeping track of the number of leading blocks that have been reserved.
        // At least one block must have been reserved to consider this function successfull.
        // Note: blocks that are reserved for the train and its wagons do not count against that count.
        var numberOfLeadingBlocksReserved = 0
        
        for step in stepsToReserve {
            guard let block = self.block(for: step.blockId) else {
                throw LayoutError.blockNotFound(blockId: step.blockId)
            }
                   
            guard block.enabled else {
                return numberOfLeadingBlocksReserved > 0
            }

            if block.isOccupied(by: train.id) {
                // The block is already reserved and contains a portion of the train
                // Note: we are not incrementing `numberOfLeadingBlocksReserved` because
                // an occupied block does not count as a "leading" block; it is occupied because
                // the train (or portion of it) occupies it.
                BTLogger.debug("Already occupied (and reserved) \(previousStep.blockId) to \(block.id) for \(train.name)")
            } else {
                guard block.reserved == nil else {
                    return numberOfLeadingBlocksReserved > 0
                }
                
                guard block.train == nil else {
                    return numberOfLeadingBlocksReserved > 0
                }

                // The block is empty, try to reserve it.
                // Note: it is possible for this call to throw an exception if it cannot reserve.
                // Catch it and return false instead as this is not an error we want to report back to the runtime
                do {
                    try reserve(trainId: train.id, fromBlock: previousStep.blockId, toBlock: block.id, direction: previousStep.direction)
                    BTLogger.debug("Reserved \(previousStep.blockId) to \(block.id) for \(train.name)")
                    numberOfLeadingBlocksReserved += 1
                } catch {
                    BTLogger.debug("Cannot reserve block \(previousStep.blockId) to \(block.id) for \(train.name): \(error)")
                    return numberOfLeadingBlocksReserved > 0
                }
            }

            // Stop reserving as soon as a block that is going to
            // stop the train is detected. That way, the train stops
            // without reserving any block ahead and upon restarting,
            // it will reserve what it needs in front of it.
            guard !trainShouldStop(train: train, block: block) else {
                return numberOfLeadingBlocksReserved > 0
            }

            // Stop once we have reached the maximum number of leading blocks to reserve
            if numberOfLeadingBlocksReserved >= train.maxNumberOfLeadingReservedBlocks {
                break
            }
            
            previousStep = step
        }
        
        return numberOfLeadingBlocksReserved > 0
    }
    
    // This method reserves and occupies all the necessary blocks (and parts of the block) to fit
    // the specified train with all its length, taking into account the length of each block.
    func fillBlocks(train: Train) throws {
        guard let fromBlockId = train.blockId else {
            throw LayoutError.trainNotAssignedToABlock(trainId: train.id)
        }
        
        guard let fromBlock = self.block(for: fromBlockId) else {
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

        let visitor = ElementVisitor(layout: self)
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
        let visitor = ElementVisitor(layout: self)
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
        blockMap.values
            .filter { $0.reserved?.trainId == train.id }
            .forEach { block in
                // Only free a block if the block is not the one the train is located on or
                if block.id != train.blockId {
                    block.reserved = nil
                    block.train = nil
                }
            }
        turnouts.filter { $0.reserved == train.id }.forEach { $0.reserved = nil; $0.train = nil }
        transitions.filter { $0.reserved == train.id }.forEach { $0.reserved = nil; $0.train = nil }
    }
    
}
