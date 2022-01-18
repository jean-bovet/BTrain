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
    func setTrain(_ train: Train, toPosition position: Int) throws
    func setTrain(_ train: Train, speed: TrainSpeed.UnitKph) throws
    func setTrain(_ train: Train, routeIndex: Int) throws
    
    // Returns the direction of the train within the block (not the train direction itself
    // but the direction of the train relative the natural direction of the block)
    func directionDirectionInBlock(_ train: Train) throws -> Direction
    
    // Toggle the direction of the train within the block itself
    func toggleTrainDirectionInBlock(_ train: Train) throws
    
    // Set the train direction (does not affect the direction of the train
    // within the block it might find itself)
    func setTrain(_ train: Train, direction: Direction) throws

    func start(routeID: Identifier<Route>, trainID: Identifier<Train>, destination: Destination?) throws

    // Stop the specified train. If completely is true,
    // set the state running to false of the train which means
    // it won't restart anymore.
    func stopTrain(_ trainId: Identifier<Train>, completely: Bool) throws

    // Use this method to stop the train when it finishes the route
    func finishTrain(_ trainId: Identifier<Train>) throws

    func setTrain(_ trainId: Identifier<Train>, toBlock toBlockId: Identifier<Block>, position: Position, direction: Direction) throws

    func reserve(block: Identifier<Block>, withTrain train: Train, direction: Direction) throws
    func reserve(train: Identifier<Train>, fromBlock: Identifier<Block>, toBlock: Identifier<Block>, direction: Direction) throws
    
    func free(fromBlock: Identifier<Block>, toBlockNotIncluded: Identifier<Block>, direction: Direction) throws
    func free(block: Identifier<Block>) throws
    
    // This method will free all the blocks reserved by the specified train.
    // If `removeFromLayout` is false, the train stays in its current block,
    // otherwise it is removed from the layout (but not from the list of trains!)
    func free(trainID: Identifier<Train>, removeFromLayout: Bool) throws
}

extension Layout: LayoutTrainHandling {
    
    func setTrain(_ train: Train, toPosition position: Int) throws {
        try trainHandling.setTrain(train, toPosition: position)
    }
    
    func setTrain(_ train: Train, speed: TrainSpeed.UnitKph) throws {
        try trainHandling.setTrain(train, speed: speed)
    }

    func setTrain(_ train: Train, routeIndex: Int) throws {
        try trainHandling.setTrain(train, routeIndex: routeIndex)
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

    func setTrain(_ train: Train, direction: Direction) throws {
        try trainHandling.setTrain(train, direction: direction)
    }
    
    func stopTrain(_ trainId: Identifier<Train>, completely: Bool = false) throws {
        try trainHandling.stopTrain(trainId, completely: completely)
    }

    func finishTrain(_ trainId: Identifier<Train>) throws {
        try trainHandling.finishTrain(trainId)
    }

    func setTrain(_ trainId: Identifier<Train>, toBlock toBlockId: Identifier<Block>, position: Position = .start, direction: Direction) throws {
        try trainHandling.setTrain(trainId, toBlock: toBlockId, position: position, direction: direction)
    }

    func reserve(block: Identifier<Block>, withTrain train: Train, direction: Direction) throws {
        try trainHandling.reserve(block: block, withTrain: train, direction: direction)
    }

    func reserve(train: Identifier<Train>, fromBlock: Identifier<Block>, toBlock: Identifier<Block>, direction: Direction) throws {
        try trainHandling.reserve(train: train, fromBlock: fromBlock, toBlock: toBlock, direction: direction)
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
    
    func setTrain(_ train: Train, toPosition position: Int) throws {
        guard let train = layout.train(for: train.id) else {
            throw LayoutError.trainNotFound(trainId: train.id)
        }
        train.position = position
        layout.didChange()
    }
    
    func setTrain(_ train: Train, speed: TrainSpeed.UnitKph) throws {
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
    
    func setTrain(_ train: Train, direction: Direction) throws {
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
            train.routeIndex = -1
            for (index, step) in route.steps.enumerated() {
                if train.blockId == step.blockId {
                    train.routeIndex = index
                    break
                }
            }
                                 
            guard train.routeIndex >= 0 else {
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

    func setTrain(_ train: Train, routeIndex: Int) throws {
        guard let train = layout.train(for: train.id) else {
            throw LayoutError.trainNotFound(trainId: train.id)
        }
        train.routeIndex = routeIndex
    }

    func setTrain(_ trainId: Identifier<Train>, toBlock toBlockId: Identifier<Block>, position: Position = .start, direction: Direction) throws {
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

        if let fromBlock = layout.block(for: trainId) {
            toBlock.train = Block.TrainInstance(trainId, direction)
            try reserve(block: toBlockId, withTrain: train, direction: direction)
            
            if fromBlock != toBlock {
                // Only reset when the train is moved to a different block,
                // not when changing its position within a block
                let direction = fromBlock.train?.direction ?? .next
                fromBlock.train = nil
                try free(fromBlock: fromBlock.id, toBlockNotIncluded: toBlockId, direction: direction)
            }
        } else {
            toBlock.train = Block.TrainInstance(trainId, direction)
            try reserve(block: toBlockId, withTrain: train, direction: direction)
        }
    }
    
    func reserve(block: Identifier<Block>, withTrain train: Train, direction: Direction) throws {
        guard let b1 = layout.block(for: block) else {
            throw LayoutError.blockNotFound(blockId: block)
        }
        
        if let reserved = b1.reserved, reserved.trainId != train.id {
            throw LayoutError.cannotReserveBlock(blockId: block, trainId: train.id, reserved: reserved)
        }
        
        b1.reserved = .init(trainId: train.id, direction: direction)
    }
    
    func reserve(train: Identifier<Train>, fromBlock: Identifier<Block>, toBlock: Identifier<Block>, direction: Direction) throws {
        guard let b1 = layout.block(for: fromBlock) else {
            throw LayoutError.blockNotFound(blockId: fromBlock)
        }

        guard let b2 = layout.block(for: toBlock) else {
            throw LayoutError.blockNotFound(blockId: toBlock)
        }

        let reservation = Reservation(trainId: train, direction: direction)
        guard b1.reserved == nil || b1.reserved == reservation else {
            throw LayoutError.cannotReserveBlock(blockId: b1.id, trainId: train, reserved: b1.reserved!)
        }
        
        guard b2.reserved == nil || b2.reserved == reservation else {
            throw LayoutError.cannotReserveBlock(blockId: b2.id, trainId: train, reserved: b2.reserved!)
        }

        let transitions = try layoutTransitioning.transitions(from: b1, to: b2, direction: direction)
        guard transitions.count > 0 else {
            throw LayoutError.noTransition(fromBlockId: b1.id, toBlockId: b2.id)
        }
        
        try Transition.canReserve(transitions: transitions, for: train, layout: layout)
                
        b1.reserved = Reservation(trainId: train, direction: direction)

        for (index, transition) in transitions.enumerated() {
            transition.reserved = train
            
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
                turnout.reserved = train
                layout.executor?.sendTurnoutState(turnout: turnout) { }
            } else if let blockId = transition.b.block {
                guard let block = layout.block(for: blockId) else {
                    throw LayoutError.blockNotFound(blockId: blockId)
                }
                let naturalDirection = transition.b.socketId == Block.previousSocket
                block.reserved = Reservation(trainId: train, direction: naturalDirection ? .next : .previous)
            }
        }
        
        guard b2.reserved?.trainId == train else {
            throw LayoutError.blockNotReservedForTrain(block: b2, train: train)
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
    
    func free(block: Identifier<Block>) throws {
        guard let b1 = layout.block(for: block) else {
            throw LayoutError.blockNotFound(blockId: block)
        }

        b1.reserved = nil
        if let train = b1.train {
            guard let train = layout.train(for: train.trainId) else {
                throw LayoutError.trainNotFound(trainId: train.trainId)
            }

            train.blockId = nil
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
