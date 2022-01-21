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

enum Position {
    case start
    case end
    case custom(value: Int)
}

protocol LayoutTrainHandling {
    func setTrainPosition(_ train: Train, _ position: Int) throws
    func setTrainSpeed(_ train: Train, _ speed: TrainSpeed.UnitKph) throws
    func setTrainRouteStepIndex(_ train: Train, _ routeIndex: Int) throws
    
    // Returns the direction of the train within the block (not the train direction itself
    // but the direction of the train relative the natural direction of the block)
    func directionDirectionInBlock(_ train: Train) throws -> Direction
    
    // Toggle the direction of the train within the block itself
    func toggleTrainDirectionInBlock(_ train: Train) throws
    
    // Set the train direction (does not affect the direction of the train
    // within the block it might find itself)
    func setTrainDirection(_ train: Train, _ direction: Direction) throws

    func start(routeID: Identifier<Route>, trainID: Identifier<Train>, destination: Destination?) throws

    // Stop the specified train. If completely is true,
    // set the state running to false of the train which means
    // it won't restart anymore.
    func stopTrain(_ trainId: Identifier<Train>, completely: Bool) throws

    // Use this method to stop the train when it finishes the route
    func finishTrain(_ trainId: Identifier<Train>) throws

    func setTrainToBlock(_ trainId: Identifier<Train>, _ toBlockId: Identifier<Block>, position: Position, direction: Direction) throws

    func reserve(block: Identifier<Block>, withTrain train: Train, direction: Direction) throws
    func reserve(trainId: Identifier<Train>, fromBlock: Identifier<Block>, toBlock: Identifier<Block>, direction: Direction) throws
    
    func freeReservedElements(fromBlockId: Identifier<Block>, direction: Direction, trainId: Identifier<Train>) throws
    
    func free(fromBlock: Identifier<Block>, toBlockNotIncluded: Identifier<Block>, direction: Direction) throws
    func free(block: Identifier<Block>) throws
    
    // This method will free all the blocks reserved by the specified train.
    // If `removeFromLayout` is false, the train stays in its current block,
    // otherwise it is removed from the layout (but not from the list of trains!)
    func free(trainID: Identifier<Train>, removeFromLayout: Bool) throws
}

extension Layout: LayoutTrainHandling {
    
    func setTrainPosition(_ train: Train, _ position: Int) throws {
        try trainHandling.setTrainPosition(train, position)
    }
    
    func setTrainSpeed(_ train: Train, _ speed: TrainSpeed.UnitKph) throws {
        try trainHandling.setTrainSpeed(train, speed)
    }

    func setTrainRouteStepIndex(_ train: Train, _ routeIndex: Int) throws {
        try trainHandling.setTrainRouteStepIndex(train, routeIndex)
    }

    func directionDirectionInBlock(_ train: Train) throws -> Direction {
        return try trainHandling.directionDirectionInBlock(train)
    }
    
    func toggleTrainDirectionInBlock(_ train: Train) throws {
        try trainHandling.toggleTrainDirectionInBlock(train)
    }

    func start(routeID: Identifier<Route>, trainID: Identifier<Train>, destination: Destination? = nil) throws {
        try trainHandling.start(routeID: routeID, trainID: trainID, destination: destination)
    }

    func setTrainDirection(_ train: Train, _ direction: Direction) throws {
        try trainHandling.setTrainDirection(train, direction)
    }
    
    func stopTrain(_ trainId: Identifier<Train>, completely: Bool = false) throws {
        try trainHandling.stopTrain(trainId, completely: completely)
    }

    func finishTrain(_ trainId: Identifier<Train>) throws {
        try trainHandling.finishTrain(trainId)
    }

    func setTrainToBlock(_ trainId: Identifier<Train>, _ toBlockId: Identifier<Block>, position: Position = .start, direction: Direction) throws {
        try trainHandling.setTrainToBlock(trainId, toBlockId, position: position, direction: direction)
    }

    func reserve(block: Identifier<Block>, withTrain train: Train, direction: Direction) throws {
        try trainHandling.reserve(block: block, withTrain: train, direction: direction)
    }

    func reserve(trainId: Identifier<Train>, fromBlock: Identifier<Block>, toBlock: Identifier<Block>, direction: Direction) throws {
        try trainHandling.reserve(trainId: trainId, fromBlock: fromBlock, toBlock: toBlock, direction: direction)
    }
     
    func freeReservedElements(fromBlockId: Identifier<Block>, direction: Direction, trainId: Identifier<Train>) throws {
        try trainHandling.freeReservedElements(fromBlockId: fromBlockId, direction: direction, trainId: trainId)
    }
    
    func free(fromBlock: Identifier<Block>, toBlockNotIncluded: Identifier<Block>, direction: Direction) throws {
        try trainHandling.free(fromBlock: fromBlock, toBlockNotIncluded: toBlockNotIncluded, direction: direction)
    }
    
    func free(block: Identifier<Block>) throws {
        try trainHandling.free(block: block)
    }

    func free(trainID: Identifier<Train>, removeFromLayout: Bool = false) throws {
        try trainHandling.free(trainID: trainID, removeFromLayout: removeFromLayout)
    }

}

final class LayoutTrainHandler: LayoutTrainHandling {
    
    private let layout: Layout
    private let layoutTransitioning: LayoutTransitionHandling
    
    init(layout: Layout, layoutTransitionController: LayoutTransitionHandling) {
        self.layout = layout
        self.layoutTransitioning = layoutTransitionController
    }
    
    func setTrainPosition(_ train: Train, _ position: Int) throws {
        guard let train = layout.train(for: train.id) else {
            throw LayoutError.trainNotFound(trainId: train.id)
        }
        train.position = position
        layout.didChange()
    }
    
    func setTrainSpeed(_ train: Train, _ speed: TrainSpeed.UnitKph) throws {
        guard let train = layout.train(for: train.id) else {
            throw LayoutError.trainNotFound(trainId: train.id)
        }
        
        train.speed.kph = speed
        layout.executor?.sendTrainSpeed(train: train)
        
        layout.didChange()
    }
    
    func directionDirectionInBlock(_ train: Train) throws -> Direction {
        guard let blockId = train.blockId else {
            throw LayoutError.trainNotAssignedToABlock(trainId: train.id)
        }
        
        guard let block = layout.block(for: blockId) else {
            throw LayoutError.blockNotFound(blockId: blockId)
        }
        
        guard let ti = block.train else {
            throw LayoutError.trainNotFoundInBlock(blockId: blockId)
        }
        
        guard ti.trainId == train.id else {
            throw LayoutError.trainInBlockDoesNotMatch(trainId: train.id, blockId: blockId, blockTrainId: ti.trainId)
        }

        return ti.direction
    }
    
    func setTrainDirection(_ train: Train, _ direction: Direction) throws {
        guard let train = layout.train(for: train.id) else {
            throw LayoutError.trainNotFound(trainId: train.id)
        }

        let forward = direction == .next
        if train.directionForward != forward {
            train.directionForward = forward
            layout.executor?.sendTrainDirection(train: train)
        }
    }
    
    func toggleTrainDirectionInBlock(_ train: Train) throws {
        guard let blockId = train.blockId else {
            throw LayoutError.trainNotAssignedToABlock(trainId: train.id)
        }
        
        guard let block = layout.block(for: blockId) else {
            throw LayoutError.blockNotFound(blockId: blockId)
        }

        guard let ti = block.train else {
            throw LayoutError.trainNotFoundInBlock(blockId: blockId)
        }

        guard ti.trainId == train.id else {
            throw LayoutError.trainInBlockDoesNotMatch(trainId: train.id, blockId: blockId, blockTrainId: ti.trainId)
        }

        block.train = Block.TrainInstance(train.id, ti.direction.opposite)

        layout.didChange()
    }
        
    func start(routeID: Identifier<Route>, trainID: Identifier<Train>, destination: Destination?) throws {
        guard let route = layout.route(for: routeID, trainId: trainID) else {
            throw LayoutError.routeNotFound(routeId: routeID)
        }
        
        guard let train = layout.train(for: trainID) else {
            throw LayoutError.trainNotFound(trainId: trainID)
        }
        
        guard let blockId = train.blockId else {
            throw LayoutError.trainNotAssignedToABlock(trainId: train.id)
        }
        
        guard let block = layout.block(for: blockId), block.train != nil else {
            throw LayoutError.trainNotFoundInBlock(blockId: blockId)
        }

        // Ensure the automatic route associated with the train is updated
        if route.automatic {
            // Remember the destination block
            if let destination = destination {
                route.automaticMode = .once(destination: destination)
            } else {
                route.automaticMode = .endless
            }
            try layout.updateAutomaticRoute(for: trainID)
        }

        // Set the route to the train
        train.routeId = routeID

        // If the route is not empty, check if the train is somewhere along the route.
        // If the blocks in front of the train are all occupied, it is possible that
        // the route is empty. The TrainController will automatically generate a new
        // route (if route.automatic) when one of the blocks is cleared.
        if !route.steps.isEmpty {
            // Check to make sure the train is somewhere along the route
            train.routeStepIndex = -1
            for (index, step) in route.steps.enumerated() {
                if train.blockId == step.blockId {
                    train.routeStepIndex = index
                    break
                }
            }
                                 
            guard train.routeStepIndex >= 0 else {
                throw LayoutError.trainNotFoundInRoute(train: train, route: route)
            }
        }

        train.scheduling = .running
    }
    
    func stopTrain(_ trainId: Identifier<Train>, completely: Bool) throws {
        guard let train = layout.train(for: trainId) else {
            throw LayoutError.trainNotFound(trainId: trainId)
        }
        
        BTLogger.debug("Stopping train \(train.name) \(completely ? "completely." : "until it can be restarted.")")
        
        train.speed.kph = 0
        layout.executor?.sendTrainSpeed(train: train)

        train.state = .stopped

        if completely {
            train.scheduling = .stopped
            try layout.free(trainID: train.id)
        }
        
        layout.didChange()
    }

    func finishTrain(_ trainId: Identifier<Train>) throws {
        guard let train = layout.train(for: trainId) else {
            throw LayoutError.trainNotFound(trainId: trainId)
        }

        train.scheduling = .finishing
    }

    func setTrainRouteStepIndex(_ train: Train, _ routeIndex: Int) throws {
        guard let train = layout.train(for: train.id) else {
            throw LayoutError.trainNotFound(trainId: train.id)
        }
        train.routeStepIndex = routeIndex
    }

    // Note: this method does not free the previous block where the train is located. This is the responsibility of the caller.
    func setTrainToBlock(_ trainId: Identifier<Train>, _ toBlockId: Identifier<Block>, position: Position = .start, direction: Direction) throws {
        guard let train = layout.train(for: trainId) else {
            throw LayoutError.trainNotFound(trainId: trainId)
        }
        
        guard let toBlock = layout.block(for: toBlockId) else {
            throw LayoutError.blockNotFound(blockId: toBlockId)
        }

        guard toBlock.train == nil || toBlock.train?.trainId == trainId else {
            throw LayoutError.blockNotEmpty(blockId: toBlockId)
        }
                
        defer {
            layout.didChange()
        }
        
        switch(position) {
        case .start:
            train.position = 0
        case .end:
            train.position = toBlock.feedbacks.count
        case .custom(value: let value):
            train.position = value
        }

        // Return now if the train is already in the same block
        if toBlock.train?.trainId == trainId {
            // But ensure the direction is well set
            if toBlock.train?.direction != direction {
                toBlock.train = Block.TrainInstance(trainId, direction)
            }
            return
        }

        train.blockId = toBlock.id

        toBlock.train = Block.TrainInstance(trainId, direction)
        try reserve(block: toBlockId, withTrain: train, direction: direction)
    }
    
    func reserve(block: Identifier<Block>, withTrain train: Train, direction: Direction) throws {
        guard let b1 = layout.block(for: block) else {
            throw LayoutError.blockNotFound(blockId: block)
        }
        
        if let reserved = b1.reserved, reserved.trainId != train.id {
            throw LayoutError.cannotReserveBlock(block: b1, train: train, reserved: reserved)
        }
        
        b1.reserved = .init(trainId: train.id, direction: direction)
    }
    
    func reserve(trainId: Identifier<Train>, fromBlock: Identifier<Block>, toBlock: Identifier<Block>, direction: Direction) throws {
        guard let b1 = layout.block(for: fromBlock) else {
            throw LayoutError.blockNotFound(blockId: fromBlock)
        }

        guard let b2 = layout.block(for: toBlock) else {
            throw LayoutError.blockNotFound(blockId: toBlock)
        }

        guard let train = layout.train(for: trainId) else {
            throw LayoutError.trainNotFound(trainId: trainId)
        }
        let reservation = Reservation(trainId: trainId, direction: direction)
        guard b1.reserved == nil || b1.reserved == reservation else {
            throw LayoutError.cannotReserveBlock(block: b1, train: train, reserved: b1.reserved!)
        }
        
        guard b2.reserved == nil || b2.reserved == reservation else {
            throw LayoutError.cannotReserveBlock(block: b2, train: train, reserved: b2.reserved!)
        }

        let transitions = try layoutTransitioning.transitions(from: b1, to: b2, direction: direction)
        guard transitions.count > 0 else {
            throw LayoutError.noTransition(fromBlockId: b1.id, toBlockId: b2.id)
        }
        
        try Transition.canReserve(transitions: transitions, for: trainId, layout: layout)
                
        b1.reserved = Reservation(trainId: trainId, direction: direction)

        for (index, transition) in transitions.enumerated() {
            transition.reserved = trainId
            
            if let turnoutId = transition.b.turnout {
                guard let turnout = layout.turnout(for: turnoutId) else {
                    throw LayoutError.turnoutNotFound(turnoutId: turnoutId)
                }
                let nextTransition = transitions[index+1]
                
                guard let fromSocket = transition.b.socketId else {
                    throw LayoutError.socketIdNotFound(socket: transition.b)
                }
                
                guard let toSocket = nextTransition.a.socketId else {
                    throw LayoutError.socketIdNotFound(socket: transition.a)
                }
                
                let state = turnout.state(fromSocket: fromSocket, toSocket: toSocket)
                turnout.state = state
                turnout.reserved = trainId
                layout.executor?.sendTurnoutState(turnout: turnout) { }
                BTLogger.debug("Reserved turnout \(turnout.name) for \(reservation) and state \(state)")
            } else if let blockId = transition.b.block {
                guard let block = layout.block(for: blockId) else {
                    throw LayoutError.blockNotFound(blockId: blockId)
                }
                let naturalDirection = transition.b.socketId == Block.previousSocket
                let reservation = Reservation(trainId: trainId, direction: naturalDirection ? .next : .previous)
                block.reserved = reservation
                BTLogger.debug("Reserved block \(block.name) for \(reservation)")
            }
        }
        
        guard b2.reserved?.trainId == trainId else {
            throw LayoutError.blockNotReservedForTrain(block: b2, train: trainId)
        }
    }
    
    func free(fromBlock: Identifier<Block>, toBlockNotIncluded: Identifier<Block>, direction: Direction) throws {
        guard let b1 = layout.block(for: fromBlock) else {
            throw LayoutError.blockNotFound(blockId: fromBlock)
        }

        guard let b2 = layout.block(for: toBlockNotIncluded) else {
            throw LayoutError.blockNotFound(blockId: toBlockNotIncluded)
        }

        let transitions = try layoutTransitioning.transitions(from: b1, to: b2, direction: direction)
        if transitions.count > 0 {
            for transition in transitions {
                transition.reserved = nil
                if let turnoutId = transition.b.turnout {
                    guard let turnout = layout.turnout(for: turnoutId) else {
                        throw LayoutError.turnoutNotFound(turnoutId: turnoutId)
                    }
                    turnout.reserved = nil
                }
            }
        } else {
            BTLogger.debug("No transition found between \(b1) and \(b2), direction \(direction)")
        }
        
        try free(block: b1.id)
    }
    
    func freeReservedElements(fromBlockId: Identifier<Block>, direction: Direction, trainId: Identifier<Train>) throws {
        guard let block = layout.block(for: fromBlockId) else {
            throw LayoutError.blockNotFound(blockId: fromBlockId)
        }
        let fromSocket = direction == .next ? block.next : block.previous
        try freeReservedElements(fromSocket: fromSocket, trainId: trainId)
    }
    
    func freeReservedElements(fromSocket: Socket, trainId: Identifier<Train>) throws {
        let transitions = try layout.transitions(from: fromSocket, to: nil).filter { $0.reserved == trainId }
        if transitions.isEmpty {
            return
        } else if transitions.count > 1 {
            throw LayoutError.alwaysOneAndOnlyOneTransition
        } else {
            let transition = transitions[0]
            
            // Free the transition
            transition.reserved = nil

            // Transitions are always ordered with a being "from" and b "to" - see layout.transitions() method
            guard let toSocketId = transition.b.socketId else {
                // TODO: have an exception for this
                fatalError()
            }
            
            if let blockId = transition.b.block {
                // Transition is leading to a block
                guard let block = layout.block(for: blockId) else {
                    throw LayoutError.blockNotFound(blockId: blockId)
                }

                // Block must be reserved for the trainId
                guard block.reserved?.trainId == trainId else {
                    return
                }
                
                // Free the block
                block.reserved = nil
                
                // Recursively call this method again to continue the job in the next element
                if toSocketId == block.previous.socketId {
                    try freeReservedElements(fromSocket: block.next, trainId: trainId)
                } else {
                    try freeReservedElements(fromSocket: block.previous, trainId: trainId)
                }
            } else if let turnoutId = transition.b.turnout {
                // Transition is leading to a turnout
                guard let turnout = layout.turnout(for: turnoutId) else {
                    throw LayoutError.turnoutNotFound(turnoutId: turnoutId)
                }

                // Turnout must be reserved for the trainId
                guard turnout.reserved == trainId else {
                    return
                }
                
                // Free the turnout
                turnout.reserved = nil
                                    
                // Find out the exit socket of the turnout given its state
                guard let socketId = turnout.socketId(fromSocketId: toSocketId, withState: turnout.state) else {
                    // TODO: have an exception for this
                    fatalError()
                }
                
                // Recursively call this method again to continue the job in the next element
                try freeReservedElements(fromSocket: turnout.socket(socketId), trainId: trainId)
            }
        }
    }
    
    func free(block: Identifier<Block>) throws {
        guard let b1 = layout.block(for: block) else {
            throw LayoutError.blockNotFound(blockId: block)
        }

        BTLogger.debug("Freeing block \(b1.name)")
        
        b1.reserved = nil
        if let blockTrain = b1.train {
            guard let train = layout.train(for: blockTrain.trainId) else {
                throw LayoutError.trainNotFound(trainId: blockTrain.trainId)
            }
            // Remove the block assignment from the train if the train is located in the block
            if train.blockId == b1.id {
                train.blockId = nil
            }
            b1.train = nil
        }
    }
    
    func free(trainID: Identifier<Train>, removeFromLayout: Bool) throws {
        guard let train = layout.train(for: trainID) else {
            throw LayoutError.trainNotFound(trainId: trainID)
        }

        // Remove the train from the blocks
        layout.blockMap.values.filter { $0.reserved?.trainId == train.id }.forEach { block in
            // Only free a block if the block is not the one the train is located on or
            // if `removeFromLayout` is true because the train must be removed from all the blocks.
            if block.id != train.blockId || removeFromLayout {
                block.reserved = nil
                block.train = nil
            }
        }
        layout.turnouts.filter { $0.reserved == train.id }.forEach { $0.reserved = nil }
        layout.transitions.filter { $0.reserved == train.id }.forEach { $0.reserved = nil }

        if removeFromLayout {
            train.blockId = nil
        }
        
        layout.didChange()
    }

}
