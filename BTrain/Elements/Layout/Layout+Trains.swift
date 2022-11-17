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

extension Layout {
    
    @discardableResult
    func newTrain() -> Train {
        let id = LayoutIdentity.newIdentity(trains.elements, prefix: .train)
        return trains.add(Train(id: id, name: id.uuid))
    }
        
    @discardableResult
    func duplicate(train: Train) -> Train {
        let nt = Train(name: "\(train.name) copy")
        nt.routeId = train.routeId
        nt.locomotive = train.locomotive
        nt.wagonsLength = train.wagonsLength
        nt.maxNumberOfLeadingReservedBlocks = train.maxNumberOfLeadingReservedBlocks
        nt.blocksToAvoid = train.blocksToAvoid
        nt.turnoutsToAvoid = train.turnoutsToAvoid
        return trains.add(nt)
    }

    func delete(trainId: Identifier<Train>) {
        try? remove(trainId: trainId)
        trains.remove(trainId)
    }
     
    // Returns the new position of the train given the specified feedback. This is used
    // to follow the train within a block when feedbacks are activated when the locomotive moves.
    //      ╲       ██            ██            ██
    //       ╲      ██            ██            ██
    //────────■─────██────────────██────────────██────────────▶
    //       ╱   0  ██     1      ██     2      ██     3
    //      ╱       ██            ██            ██     ▲
    //              0             1             2      │
    //                            ▲                    │
    //                            │                    │
    //                            │                    │
    //
    //                     Feedback Index       Train Position
    func newPosition(forTrain train: Train, enabledFeedbackIndex: Int, direction: Direction) -> Int {
        let strict = strictRouteFeedbackStrategy

        switch(direction) {
        case .previous:
            let delta = train.position - enabledFeedbackIndex
            if strict && delta == 1 {
                // this is the feedback in front of the train, it means
                // the train has moved past this feedback
                return train.position - delta
            }
            if !strict && delta > 0 {
                // A feedback in front of the train has been activated.
                // When not in strict mode, we update the position of the train.
                return train.position - delta
            }

        case .next:
            let delta = enabledFeedbackIndex - train.position
            if strict && delta == 0 {
                // this is the feedback in front of the train, it means
                // the train has moved past this feedback
                return train.position + 1
            }
            if !strict && delta >= 0 {
                // A feedback in front of the train has been activated.
                // When not in strict mode, we update the position of the train.
                return train.position + delta + 1
            }
        }
        
        return train.position
    }
            
    func hasTrainReachedStationOrDestination(_ route: Route?, _ train: Train, _ block: Block) -> Bool {
        if let route = route {
            switch route.mode {
            case .automaticOnce(let destination):
                if !destination.hasReached(block: block) {
                    return false
                }
            case .fixed, .automatic:
                if block.category != .station {
                    return false
                }
            }
        } else {
            if block.category != .station {
                return false
            }
        }

        // Check that the train is not in the first block of the route in which case
        // it should not stop at all, otherwise a train will never leave its station
        guard train.routeStepIndex != train.startRouteIndex || train.startRouteIndex == nil else {
            return false
        }

        return true
    }
    
    /// Sets a train to a specific block.
    ///
    /// - Parameters:
    ///   - trainId: the train
    ///   - toBlockId: the block in which to put the train
    ///   - position: the position in the block in which to put the train
    ///   - direction: the direction in the block in which to put the train
    ///   - routeIndex: optional index in the route
    ///   - removeLeadingBlocks: true to remove the leading blocks (by default), false to keep the leading blocks
    func setTrainToBlock(_ trainId: Identifier<Train>, _ toBlockId: Identifier<Block>, position: Position = .start, direction: Direction, routeIndex: Int? = nil) throws {
        guard let train = trains[trainId] else {
            throw LayoutError.trainNotFound(trainId: trainId)
        }
        
        guard let toBlock = self.blocks[toBlockId] else {
            throw LayoutError.blockNotFound(blockId: toBlockId)
        }

        guard toBlock.trainInstance == nil || toBlock.trainInstance?.trainId == trainId else {
            throw LayoutError.blockNotEmpty(blockId: toBlockId)
        }
                
        guard toBlock.reservation == nil || toBlock.reservation?.trainId == train.id else {
            throw LayoutError.cannotReserveBlock(block: toBlock, train: train, reserved: toBlock.reservation!)
        }
        
        // Determine the position of the train
        switch(position) {
        case .start:
            train.position = direction == .next ? 0 : toBlock.feedbacks.count
        case .end:
            train.position = direction == .next ? toBlock.feedbacks.count : 0
        case .custom(value: let value):
            train.position = value
        }

        // Reserve the block
        toBlock.reservation = .init(trainId: train.id, direction: direction)
        toBlock.trainInstance = TrainInstance(trainId, direction)

        // Assign the block to the train
        train.blockId = toBlock.id
        
        // Update the route index if specified
        if let routeIndex = routeIndex {
            train.routeStepIndex = routeIndex
        }
    }

    func free(fromBlock: Identifier<Block>, toBlockNotIncluded: Identifier<Block>, direction: Direction) throws {
        guard let b1 = self.blocks[fromBlock] else {
            throw LayoutError.blockNotFound(blockId: fromBlock)
        }

        guard let b2 = self.blocks[toBlockNotIncluded] else {
            throw LayoutError.blockNotFound(blockId: toBlockNotIncluded)
        }

        let transitions = try self.transitions(from: LayoutVector(block: b1, direction: direction), to: LayoutVector(block: b2, direction: nil))
        if transitions.count > 0 {
            for transition in transitions {
                transition.reserved = nil
                if let turnoutId = transition.b.turnout {
                    guard let turnout = turnouts[turnoutId] else {
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
        guard let b1 = self.blocks[block] else {
            throw LayoutError.blockNotFound(blockId: block)
        }

        BTLogger.debug("Freeing block \(b1.name)")
        
        b1.reservation = nil
        if let blockTrain = b1.trainInstance {
            guard let train = trains[blockTrain.trainId] else {
                throw LayoutError.trainNotFound(trainId: blockTrain.trainId)
            }
            // Remove the block assignment from the train if the train is located in the block
            if train.blockId == b1.id {
                train.blockId = nil
            }
            b1.trainInstance = nil
        }
    }
    
    // Remove the train from the layout (but not from the list of train)
    func remove(trainId: Identifier<Train>) throws {
        guard let train = trains[trainId] else {
            throw LayoutError.trainNotFound(trainId: trainId)
        }
        
        // Remove the train from the blocks
        blocks.elements
            .filter { $0.reservation?.trainId == train.id }
            .forEach { block in
                block.reservation = nil
                block.trainInstance = nil
            }
        turnouts.elements.filter { $0.reserved?.train == train.id }.forEach { $0.reserved = nil; $0.train = nil }
        transitions.elements.filter { $0.reserved == train.id }.forEach { $0.reserved = nil; $0.train = nil }
        
        train.blockId = nil
    }

    func block(for train: Train, step: RouteItem) -> (Identifier<Block>, Direction)? {
        switch step {
        case .block(let stepBlock):
            return (stepBlock.blockId, stepBlock.direction)

        case .station(let stepStation):
            guard let station = stations[stepStation.stationId] else {
                return nil
            }
            guard let item = station.blockWith(train: train, layout: self) else {
                return nil
            }
            
            guard let bid = item.blockId, let bd = item.direction else {
                return nil
            }
            
            return (bid, bd)
            
        case .turnout(_):
            return nil
        }
    }
}
