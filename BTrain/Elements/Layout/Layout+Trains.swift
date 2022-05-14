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
        let id = LayoutIdentity.newIdentity(trains, prefix: .train)
        return addTrain(Train(id: id, name: id.uuid, address: 0))
    }
    
    @discardableResult
    func addTrain(_ train: Train) -> Train {
        trains.append(train)
        return train
    }
    
    func train(for trainId: Identifier<Train>?) -> Train? {
        return trains.first(where: { $0.id == trainId })
    }

    func remove(trainId: Identifier<Train>) {
        try? remove(trainID: trainId)
        trains.removeAll(where: { $0.id == trainId})
    }
    
    func sortTrains() {
        trains.sort {
            $0.name < $1.name
        }
    }

    func removeAllTrains() {
        trains.forEach {
            try? remove(trainID: $0.id)
        }
    }
    
    func setTrainPosition(_ train: Train, _ position: Int) throws {
        train.position = position
        
        try reservation.removeLeadingBlocks(train: train)

        didChange()
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
            
    /// Adjusts the speed of the train to the maximum allowed speed authorized.
    ///
    /// The maximum speed takes several factors into condition, including the blocks and turnouts
    /// speed restrictions that the train is located on, as well as the leading reserved blocks distance
    /// to make sure the train has enough distance to safely brake to a halt if necessary.
    ///
    /// This method only affects trains running in automatic scheduling. Manual scheduling is not monitored.
    /// - Parameter train: the train to adjust the speed
    func adjustSpeedLimit(_ train: Train) {
        // Note: only do that when the train is not under manual control!
        guard !train.unmanagedScheduling else {
            return
        }

        if train.state == .running {
            setTrainSpeed(train, LayoutFactory.DefaultMaximumSpeed, speedLimit: true) { }
        }
    }
    
    func setTrainSpeed(_ train: Train, _ speed: TrainSpeed.UnitKph, speedLimit: Bool = true, force: Bool = false, acceleration: TrainSpeedAcceleration.Acceleration? = nil, completion: @escaping CompletionBlock) {
        let previousRequestedSteps = train.speed.requestedSteps
        if speedLimit {
            let route = route(for: train.routeId, trainId: train.id)
            train.speed.requestedKph = min(speed, reservation.maximumSpeedAllowed(train: train, route: route))
        } else {
            train.speed.requestedKph = speed
        }
        if train.speed.requestedSteps != previousRequestedSteps || force {
            setTrainSpeed(train, train.speed.requestedSteps, acceleration: acceleration, completion: completion)
        } else {
            completion()
        }
    }

    func setTrainSpeed(_ train: Train, _ speed: SpeedStep, acceleration: TrainSpeedAcceleration.Acceleration? = nil, completion: @escaping CompletionBlock) {
        train.speed.requestedSteps = speed
        if train.speed.requestedSteps != train.speed.actualSteps {
            executor.sendTrainSpeed(train: train, acceleration: acceleration) { [weak self] in
                self?.didChange()
                completion()
            }
        } else {
            completion()
        }
    }

    // Returns the direction of the train within the block (not the train direction itself
    // but the direction of the train relative the natural direction of the block)
    func directionDirectionInBlock(_ train: Train) throws -> Direction {
        guard let blockId = train.blockId else {
            throw LayoutError.trainNotAssignedToABlock(train: train)
        }
        
        guard let block = self.block(for: blockId) else {
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
    
    // Set the direction of travel of the locomotive
    func setLocomotiveDirection(_ train: Train, forward: Bool, completion: CompletionBlock? = nil) {
        if train.directionForward != forward {
            executor.sendTrainDirection(train: train, forward: forward) {
                completion?()
            }
        } else {
            completion?()
        }
    }
    
    // Toggle the direction of the train within the block itself
    func toggleTrainDirectionInBlock(_ train: Train) throws {
        guard let blockId = train.blockId else {
            throw LayoutError.trainNotAssignedToABlock(train: train)
        }
        
        guard let block = self.block(for: blockId) else {
            throw LayoutError.blockNotFound(blockId: blockId)
        }

        guard let ti = block.train else {
            throw LayoutError.trainNotFoundInBlock(blockId: blockId)
        }

        guard ti.trainId == train.id else {
            throw LayoutError.trainInBlockDoesNotMatch(trainId: train.id, blockId: blockId, blockTrainId: ti.trainId)
        }

        block.train = TrainInstance(train.id, ti.direction.opposite)
        train.wagonsPushedByLocomotive.toggle()

        try reservation.removeLeadingBlocks(train: train)

        self.didChange()
    }
        
    func start(routeID: Identifier<Route>, trainID: Identifier<Train>, destination: Destination? = nil) throws {
        guard let route = self.route(for: routeID, trainId: trainID) else {
            throw LayoutError.routeNotFound(routeId: routeID)
        }
        
        guard let train = self.train(for: trainID) else {
            throw LayoutError.trainNotFound(trainId: trainID)
        }
        
        guard let blockId = train.blockId else {
            throw LayoutError.trainNotAssignedToABlock(train: train)
        }
        
        guard let block = self.block(for: blockId), block.train != nil else {
            throw LayoutError.trainNotFoundInBlock(blockId: blockId)
        }

        // Set the route to the train
        train.routeId = routeID

        if route.automatic {
            // Ensure the automatic route associated with the train is updated
            // Note: remember the destination block
            if let destination = destination {
                route.mode = .automaticOnce(destination: destination)
            } else {
                route.mode = .automatic
            }
            
            // Reset the route - the route will be automatically updated by
            // the TrainController when the train is started.
            train.routeStepIndex = 0
            route.steps.removeAll()
        } else {
            // Check to make sure the train is somewhere along the route
            train.routeStepIndex = -1
            for (index, step) in route.steps.enumerated() {
                guard let (blockId, direction) = self.block(for: train, step: step) else {
                    continue
                }
                
                guard train.blockId == blockId else {
                    continue
                }
                
                guard let block = self.block(for: train.blockId) else {
                    continue
                }

                guard let trainInstance = block.train else {
                    continue
                }
                
                // Check that the train direction matches as well.
                if trainInstance.direction == direction {
                    train.routeStepIndex = index
                    break
                }
            }
                                 
            guard train.routeStepIndex >= 0 else {
                throw LayoutError.trainNotFoundInRoute(train: train, route: route)
            }
        }

        train.scheduling = .managed(finishing: false)
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

    // Stop the specified train. If completely is true,
    // set the state running to false of the train which means
    // it won't restart anymore.
    func stopTrain(_ trainId: Identifier<Train>, completely: Bool = false, completion: @escaping CompletionBlock) throws {
        guard let train = self.train(for: trainId) else {
            throw LayoutError.trainNotFound(trainId: trainId)
        }
                
        BTLogger.router.debug("\(train): stopping \(completely ? "completely." : "until it can be restarted.")")

        if train.state != .stopped && train.state != .stopping {
            train.speed.requestedKph = 0
            train.state = .stopping

            executor.sendTrainSpeed(train: train, acceleration: nil) { [weak self] in
                train.state = .stopped
                self?.didChange()
                completion()
            }
        } else {
            completion()
        }

        if completely {
            try stopCompletely(trainId)
        }
        
        self.didChange()
    }

    func stopCompletely(_ trainId: Identifier<Train>) throws {
        guard let train = self.train(for: trainId) else {
            throw LayoutError.trainNotFound(trainId: trainId)
        }
        
        train.scheduling = .unmanaged
        try reservation.removeLeadingBlocks(train: train)
    }
    
    // Use this method to stop the train when it finishes the route
    func finishTrain(_ trainId: Identifier<Train>) throws {
        guard let train = self.train(for: trainId) else {
            throw LayoutError.trainNotFound(trainId: trainId)
        }

        train.scheduling = .managed(finishing: true)
    }

    // This method sets the train in a specific block and updates the reserved blocks (occupied and leading blocks).
    func setTrainToBlock(_ trainId: Identifier<Train>, _ toBlockId: Identifier<Block>, position: Position = .start, direction: Direction, routeIndex: Int? = nil) throws {
        guard let train = self.train(for: trainId) else {
            throw LayoutError.trainNotFound(trainId: trainId)
        }
        
        guard let toBlock = self.block(for: toBlockId) else {
            throw LayoutError.blockNotFound(blockId: toBlockId)
        }

        guard toBlock.train == nil || toBlock.train?.trainId == trainId else {
            throw LayoutError.blockNotEmpty(blockId: toBlockId)
        }
                
        guard toBlock.reserved == nil || toBlock.reserved?.trainId == train.id else {
            throw LayoutError.cannotReserveBlock(block: toBlock, train: train, reserved: toBlock.reserved!)
        }

        defer {
            didChange()
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
        toBlock.reserved = .init(trainId: train.id, direction: direction)
        toBlock.train = TrainInstance(trainId, direction)

        // Assign the block to the train
        train.blockId = toBlock.id
        
        // Update the route index if specified
        if let routeIndex = routeIndex {
            train.routeStepIndex = routeIndex
        }

        try reservation.removeLeadingBlocks(train: train)
    }

    func free(fromBlock: Identifier<Block>, toBlockNotIncluded: Identifier<Block>, direction: Direction) throws {
        guard let b1 = self.block(for: fromBlock) else {
            throw LayoutError.blockNotFound(blockId: fromBlock)
        }

        guard let b2 = self.block(for: toBlockNotIncluded) else {
            throw LayoutError.blockNotFound(blockId: toBlockNotIncluded)
        }

        let transitions = try self.transitions(from: b1, to: b2, direction: direction)
        if transitions.count > 0 {
            for transition in transitions {
                transition.reserved = nil
                if let turnoutId = transition.b.turnout {
                    guard let turnout = self.turnout(for: turnoutId) else {
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
        guard let b1 = self.block(for: block) else {
            throw LayoutError.blockNotFound(blockId: block)
        }

        BTLogger.debug("Freeing block \(b1.name)")
        
        b1.reserved = nil
        if let blockTrain = b1.train {
            guard let train = self.train(for: blockTrain.trainId) else {
                throw LayoutError.trainNotFound(trainId: blockTrain.trainId)
            }
            // Remove the block assignment from the train if the train is located in the block
            if train.blockId == b1.id {
                train.blockId = nil
            }
            b1.train = nil
        }
    }
    
    // Remove the train from the layout (but not from the list of train)
    func remove(trainID: Identifier<Train>) throws {
        guard let train = self.train(for: trainID) else {
            throw LayoutError.trainNotFound(trainId: trainID)
        }
        
        // Remove the train from the blocks
        blockMap.values
            .filter { $0.reserved?.trainId == train.id }
            .forEach { block in
                block.reserved = nil
                block.train = nil
            }
        turnouts.filter { $0.reserved?.train == train.id }.forEach { $0.reserved = nil; $0.train = nil }
        transitions.filter { $0.reserved == train.id }.forEach { $0.reserved = nil; $0.train = nil }
        
        train.blockId = nil
        
        didChange()
    }

    func block(for train: Train, step: RouteItem) -> (Identifier<Block>, Direction)? {
        switch step {
        case .block(let stepBlock):
            return (stepBlock.blockId, stepBlock.direction ?? .next)

        case .station(let stepStation):
            guard let station = self.station(for: stepStation.stationId) else {
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
