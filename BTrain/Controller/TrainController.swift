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

protocol TrainControllerDelegate: AnyObject {
    func scheduleRestartTimer(trainInstance: Block.TrainInstance)
}

// This class manages a single train in the layout, by starting and stopping it,
// managing the monitoring when it transition from one block to another, etc.
final class TrainController {
    
    // Most method in this class returns a result
    // that indicates if that method has done something
    // or not. This is useful information that will help
    // the LayoutController to re-run the TrainController
    // in case there is any changes to be applied.
    enum Result {
        case none
        case processed
    }
    
    let layout: Layout
    let train: Train
    weak var delegate: TrainControllerDelegate?
    
    // Keeping track of the route index when the train starts,
    // to avoid stopping it immediately if it is still starting
    // in the first block of the route.
    var startRouteIndex: Int?
    
    // Structure indicating when the train should stop and
    // the associated behavior when it does effectively stop.
    struct StopTrigger {
        // If > 0, the train will be restarted after the specified delay
        let restartDelay: TimeInterval
        
        // If true, the train scheduling will be stopped as well,
        // otherwise the train stops temporarily until it can restart.
        let stopCompletely: Bool
        
        static func completeStop() -> StopTrigger {
            return .init(restartDelay: 0, stopCompletely: true)
        }
        
        static func temporaryStop() -> StopTrigger {
            return .init(restartDelay: 0, stopCompletely: false)
        }
        
        static func stopAndRestart(after delay: TimeInterval) -> StopTrigger {
            return .init(restartDelay: delay, stopCompletely: false)
        }

    }
    
    // If this variable is not nil, it means the train
    // has been asked to stop at the next opportunity.
    var stopTrigger: StopTrigger? = nil
    
    init(layout: Layout, train: Train, delegate: TrainControllerDelegate? = nil) {
        self.layout = layout
        self.train = train
        self.delegate = delegate
    }
            
    // This is the main method to call to manage the changes for the train.
    // If this method returns Result.processed, it is expected to be called again
    // in order to process any changes remaining.
    // Note: because each function below has a side effect that can affect
    // the currentBlock and nextBlock (as well as the train speed and other parameters),
    // always have each function retrieve what it needs.
    @discardableResult
    func run() throws -> Result {
        // Stop the train if there is no route associated with it
        guard let route = layout.route(for: train.routeId, trainId: train.id) else {
            return try stop()
        }

        // Return now if the train is not actively "running"
        guard train.scheduling != .stopped else {
            return .none
        }
        
        var result: Result = .none
        
        if try handleTrainStart() == .processed {
            result = .processed
        }

        if try handleTrainMove() == .processed {
            result = .processed
        }
        
        if try handleTrainStop() == .processed {
            result = .processed
        }
        
        if try handleTrainAutomaticRouteUpdate(route: route) == .processed {
            result = .processed
        }
        
        if try handleTrainStop() == .processed {
            result = .processed
        }

        if try handleTrainMoveToNextBlock(route: route) == .processed {
            result = .processed
        }
        
        if try handleTrainStop() == .processed {
            result = .processed
        }

        return result
    }
    
    private func handleTrainStart() throws -> Result {
        guard train.speed.kph == 0 else {
            return .none
        }

        guard let currentBlock = layout.currentBlock(train: train) else {
            return .none
        }

        guard let routeId = train.routeId else {
            return .none
        }

        guard let route = layout.route(for: routeId, trainId: train.id) else {
            return .none
        }

        guard let trainInstance = currentBlock.train else {
            return .none
        }

        // Do not start the train if there is still time for the train until it has to restart
        guard trainInstance.timeUntilAutomaticRestart == 0 else {
            return .none
        }
        
        let nextBlock = layout.nextBlock(train: train)
        
        // Update the automatic route if the next block is not defined and if the automatic route
        // does not have a destinationBlock.
        if nextBlock == nil && route.automatic && route.automaticMode == .endless {
            debug("Generating a new route for \(train) at block \(currentBlock.name) with mode \(route.automaticMode) because the next block is not defined")
            return try updateAutomaticRoute(for: train.id)
        }
                
        // Try to reserve the next blocks and if successfull, then start the train
        if try reserveNextBlocks(route: route) {
            debug("Start train \(train.name) because the next blocks could be reserved")
            startRouteIndex = train.routeStepIndex
            try layout.setTrainSpeed(train, LayoutFactory.DefaultSpeed)
            train.state = .running
            return .processed
        }
        
        return .none
    }
    
    // This method updates the automatic route, if selected, in case the next block is occupied.
    private func handleTrainAutomaticRouteUpdate(route: Route) throws -> Result {
        guard let currentBlock = layout.currentBlock(train: train) else {
            return .none
        }

        guard let nextBlock = layout.nextBlock(train: train) else {
            return .none
        }
        
        var nextBlockNotAvailable = false
        // If the next block is disabled, we need to re-compute a new route
        if !nextBlock.enabled {
            nextBlockNotAvailable = true
        }

        // If the next block contains a train, we need to re-compute a new route
        if nextBlock.train != nil {
            nextBlockNotAvailable = true
        }
        
        // If the next block is reserved for another train, we need to re-compute a new route
        if let reserved = nextBlock.reserved, reserved.trainId != train.id {
            nextBlockNotAvailable = true
        }
        
        guard nextBlockNotAvailable && route.automatic else {
            return .none
        }
        
        // Generate a new route if one is available
        debug("Generating a new route for \(train) at block \(currentBlock.name) because the next block \(nextBlock.name) is occupied or disabled")

        // Update the automatic route
        return try updateAutomaticRoute(for: train.id)
    }
        
    // This method handles any stop trigger related to the automatic route, which are:
    // - The train reaches the end of the route (that does not affect `endless` automatic route)
    // - The train reaches a block that stops the train for a while (ie station)
    private func handleAutomaticRouteStop(route: Route) throws -> Result {
        guard let currentBlock = layout.currentBlock(train: train) else {
            return .none
        }
        
        guard route.automatic else {
            return .none
        }
        
        // The train is not in the first step of the route
        guard train.routeStepIndex != startRouteIndex else {
            return .none
        }
        
        switch(route.automaticMode) {
        case .once(destination: let destination):
            if train.routeStepIndex == route.lastStepIndex {
                // Double-check that the train is located in the block specified by the destination.
                // This should never fail.
                guard currentBlock.id == destination.blockId else {
                    throw LayoutError.destinationBlockMismatch(currentBlock: currentBlock, destination: destination)
                }
                
                // Double-check that the train is moving in the direction specified by the destination, if specified.
                // This should never fail.
                if let direction = destination.direction, currentBlock.train?.direction != direction {
                    throw LayoutError.destinationDirectionMismatch(currentBlock: currentBlock, destination: destination)
                }
                                
                debug("Stopping completely \(train) because it has reached the end of the route")
                stopTrigger = StopTrigger.completeStop()
                return .processed
            }
            
        case .endless:
            if handleTrainStopByBlock(route: route, block: currentBlock) == .processed {
                return .processed
            }
        }
                                
        return .none
    }
        
    // This method handles any stop trigger related to the manual route, which are:
    // - The train reaches the end of the route
    // - The train reaches a block that stops the train for a while (ie station)
    private func handleManualRouteStop(route: Route) throws -> Result {
        guard let currentBlock = layout.currentBlock(train: train) else {
            return .none
        }
        
        guard !route.automatic else {
            return .none
        }
        
        // The train is not in the first step of the route
        guard train.routeStepIndex != startRouteIndex else {
            return .none
        }
        
        if train.routeStepIndex == route.lastStepIndex {
            debug("Train \(train) will stop here (\(currentBlock)) because it has reached the end of the route")
            stopTrigger = StopTrigger.completeStop()
            return .processed
        }
        
        if handleTrainStopByBlock(route: route, block: currentBlock) == .processed {
            return .processed
        }
        
        return .none
    }
    
    // This method takes care of trigger a stop of the train located in
    // the specified `block`, depending on the block characteristics.
    // For now, only "station" blocks make the train stop.
    private func handleTrainStopByBlock(route: Route, block: Block) -> Result {
        guard trainShouldStop(block: block) else {
            return .none
        }
        
        if train.scheduling == .finishing {
            debug("Stopping completely \(train) because it has reached a station and it is marked as .finishing")
            stopTrigger = StopTrigger.completeStop()
            return .processed
        } else {
            let delay = waitingTime(route: route, train: train, block: block)
            stopTrigger = StopTrigger.stopAndRestart(after: delay)
            return .processed
        }
    }

    private func trainShouldStop(block: Block) -> Bool {
        guard block.category == .station else {
            return false
        }

        guard train.routeStepIndex != startRouteIndex || startRouteIndex == nil else {
            return false
        }

        return true
    }
    
    private func waitingTime(route: Route, train: Train, block: Block) -> TimeInterval {
        if let step = route.steps.element(at: train.routeStepIndex), let time = step.waitingTime {
            return time
        } else {
            // Use the block waiting time if the route itself has nothing specified
            return block.waitingTime
        }
    }
        
    private func handleTrainStop() throws -> Result {
        guard train.speed.kph > 0 else {
            return .none
        }
                
        guard let currentBlock = layout.currentBlock(train: train) else {
            return .none
        }

        guard let trainInstance = currentBlock.train else {
            return .none
        }
        
        guard let stopTrigger = stopTrigger else {
            return .none
        }
        
        let direction = trainInstance.direction
        var result: Result = .none
        for (_, feedback) in currentBlock.feedbacks.enumerated() {
            guard let f = layout.feedback(for: feedback.feedbackId), f.detected else {
                continue
            }
            
            if train.state == .running {
                guard let brakeFeedback = currentBlock.brakeFeedback(for: direction) else {
                    throw LayoutError.brakeFeedbackNotFound(block: currentBlock)
                }
                if brakeFeedback == f.id {
                    debug("Train \(train) is braking in \(currentBlock.name) at position \(train.position), direction \(direction)")
                    train.state = .braking
                    try layout.setTrainSpeed(train, LayoutFactory.DefaultBrakingSpeed)
                    result = .processed
                }
            }
            
            if train.state == .braking {
                guard let stopFeedback = currentBlock.stopFeedback(for: direction) else {
                    throw LayoutError.stopFeedbackNotFound(block: currentBlock)
                }
                if stopFeedback == f.id {
                    debug("Train \(train) is stopped in \(currentBlock.name) at position \(train.position), direction \(direction)")
                    result = try stop(completely: stopTrigger.stopCompletely)
                    
                    // Reschedule if necessary
                    if stopTrigger.restartDelay > 0 {
                        debug("Schedule timer to restart train \(train) in \(stopTrigger.restartDelay) seconds")
                        
                        // The layout controller is going to schedule the appropriate timer given the `restartDelayTime` value
                        if let ti = currentBlock.train {
                            ti.timeUntilAutomaticRestart = stopTrigger.restartDelay
                            delegate?.scheduleRestartTimer(trainInstance: ti)
                        }
                    }
                }
            }
        }
        return result
    }
    
    private func handleTrainMove() throws -> Result {
        guard train.speed.kph > 0 else {
            return .none
        }
                
        guard let currentBlock = layout.currentBlock(train: train) else {
            return .none
        }

        guard let trainInstance = currentBlock.train else {
            return .none
        }
        
        let direction = trainInstance.direction
        var result: Result = .none
        for (index, feedback) in currentBlock.feedbacks.enumerated() {
            guard let f = layout.feedback(for: feedback.feedbackId), f.detected else {
                continue
            }
            
            let position = newPosition(forTrain: train, enabledFeedbackIndex: index, direction: direction)
            if train.position != position {
                try layout.setTrainPosition(train, position)
                debug("Train \(train) moved to position \(train.position) in \(currentBlock.name), direction \(direction)")
                result = .processed
            }
                        
        }
        
        return result
    }
    
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
    private func newPosition(forTrain train: Train, enabledFeedbackIndex: Int, direction: Direction) -> Int {
        let strict = layout.strictRouteFeedbackStrategy

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
    
    // This method handles the transition from one block to another, using
    // the entry feedback of the next block to determine when a train moves
    // to the next block.
    // When the train moves to another block:
    // - Trailing and leading reservation blocks are updated.
    // - Stop trigger is evaluated depending on the nature of the route
    private func handleTrainMoveToNextBlock(route: Route) throws -> Result {
        guard train.speed.kph > 0 else {
            return .none
        }
        
        guard try layout.shouldHandleTrainMoveToNextBlock(train: train) else {
            return .none
        }
        
        guard let currentBlock = layout.currentBlock(train: train) else {
            return .none
        }

        guard let nextBlock = layout.nextBlock(train: train) else {
            return .none
        }

        // Find out what is the entry feedback for the next block
        let (entryFeedback, direction) = try layout.feedbackTriggeringTransition(from: currentBlock, to: nextBlock)
        
        guard let entryFeedback = entryFeedback, entryFeedback.detected else {
            // The first feedback is not yet detected, nothing more to do
            return .none
        }
        
        guard let position = nextBlock.indexOfTrain(forFeedback: entryFeedback.id, direction: direction) else {
            throw LayoutError.feedbackNotFound(feedbackId: entryFeedback.id)
        }
                
        debug("Train \(train) enters block \(nextBlock) at position \(position), direction \(direction)")

        // Remember the current step before moving to the next block
        rememberCurrentBlock(route: route)
                
        // Set the train to its new block
        try layout.setTrainToBlock(train.id, nextBlock.id, position: .custom(value: position), direction: direction)

        // And remove the train from the previous block
        currentBlock.train = nil
        
        // Increment the train route index
        try layout.setTrainRouteStepIndex(train, train.routeStepIndex + 1)
                
        // Free up the trailing blocks        
        try freeTrailingBlocks()
                
        // Handle any route-specific stop now that the train has moved to a new block
        if route.automatic {
            _ = try handleAutomaticRouteStop(route: route)
        } else {
            _ = try handleManualRouteStop(route: route)
        }
        
        // If the train is not stopping in this block, reserve the block(s) ahead.
        if stopTrigger == nil {
            if try reserveNextBlocks(route: route) == false {
                // If it is not possible, then stop the train in this block
                debug("Train \(train) will stop here (\(nextBlock)) because the next block(s) cannot be reserved")
                stopTrigger = StopTrigger.temporaryStop()
            }
        }

        return .processed
    }
        
    private func rememberCurrentBlock(route: Route) {
        let step = route.steps[train.routeStepIndex]
        train.trailingReservedBlocks.append(.init(step.blockId, step.direction))
    }
    
    private func freeTrailingBlocks() throws {
        guard let currentBlock = layout.currentBlock(train: train) else {
            throw LayoutError.trainNotAssignedToABlock(trainId: train.id)
        }
        
        // [ b1, b2, b3 ]    // Previous visited blocks that are kept reserved
        //                b4 // Current block where the train resides
        // Free up the following blocks, in order:
        // b1-b2
        // b2-b3
        // b3-b4
        while train.trailingReservedBlocks.count > train.numberOfTrailingReservedBlocks {
            if train.trailingReservedBlocks.count >= 2 {
                let step1 = train.trailingReservedBlocks.removeFirst()
                let step2 = train.trailingReservedBlocks.first!
                try layout.free(fromBlock: step1.blockId, toBlockNotIncluded: step2.blockId, direction: step1.direction)
            } else if train.trailingReservedBlocks.count == 1 {
                let step = train.trailingReservedBlocks.removeFirst()
                try layout.free(fromBlock: step.blockId, toBlockNotIncluded: currentBlock.id, direction: step.direction)
            } else {
                break
            }
        }
    }

    private func freeLeadingReservedElements() throws {
        guard let currentBlock = layout.currentBlock(train: train) else {
            throw LayoutError.trainNotAssignedToABlock(trainId: train.id)
        }

        guard let ti = currentBlock.train else {
            throw LayoutError.trainNotFoundInBlock(blockId: currentBlock.id)
        }
        
        try layout.freeReservedElements(fromBlockId: currentBlock.id, direction: ti.direction, trainId: train.id)
    }
    
    // This function will try to reserve as many blocks as specified (maxNumberOfLeadingReservedBlocks)
    // in front of the train (leading blocks).
    // Note: it won't reserve blocks that are already reserved to avoid loops.
    private func reserveNextBlocks(route: Route) throws -> Bool {
        guard route.steps.count > 0 else {
            return false
        }

        // Before trying to reserve the leading blocks, let's free up
        // all the reserved elements (turnouts, transitions, blocks) in front
        // of the train. This is to keep the algorithm simple:
        // (1) Free up leading reserved blocks
        // (2) Reserve leading reserved blocks
        try freeLeadingReservedElements()
                
        let startReservationIndex = min(route.lastStepIndex, train.routeStepIndex + 1)
        let endReservationIndex = min(route.lastStepIndex, train.routeStepIndex + train.maxNumberOfLeadingReservedBlocks)
                
        var previousStep = route.steps[train.routeStepIndex]
        let stepsToReserve = route.steps[startReservationIndex...endReservationIndex]
        
        // Variable keeping track of the number of blocks that have been reserved.
        // At least one block must have been reserved to consider this function successfull.
        var numberOfBlocksReserved = 0
        
        for step in stepsToReserve {
            guard let block = layout.block(for: step.blockId) else {
                throw LayoutError.blockNotFound(blockId: step.blockId)
            }
            
            guard block.reserved == nil else {
                return numberOfBlocksReserved > 0
            }

            guard block.train == nil else {
                return numberOfBlocksReserved > 0
            }
            
            guard block.enabled else {
                return numberOfBlocksReserved > 0
            }

            // Note: it is possible for this call to throw an exception if it cannot reserve.
            // Catch it and return false instead as this is not an error we want to report back to the runtime
            do {
                try layout.reserve(trainId: train.id, fromBlock: previousStep.blockId, toBlock: block.id, direction: previousStep.direction)
                BTLogger.debug("Reserved \(previousStep.blockId) to \(block.id) for \(train.name)")
                numberOfBlocksReserved += 1
            } catch {
                BTLogger.debug("Cannot reserve block \(previousStep.blockId) to \(block.id) for \(train.name): \(error)")
                return numberOfBlocksReserved > 0
            }

            // Stop reserving as soon as a block that is going to
            // stop the train is detected. That way, the train stops
            // without reserving any block ahead and upon restarting,
            // it will reserve what it needs in front of it.
            guard !trainShouldStop(block: block) else {
                return numberOfBlocksReserved > 0
            }

            previousStep = step
        }
        
        return numberOfBlocksReserved > 0
    }
    
    private func stop(completely: Bool = false) throws -> Result {
        stopTrigger = nil
        
        guard train.speed.kph > 0 else {
            return .none
        }
        
        debug("Stop train \(train)")
        
        try layout.stopTrain(train.id, completely: completely)
                
        return .processed
    }
        
    private func updateAutomaticRoute(for trainId: Identifier<Train>) throws -> Result {
        let (success, route) = try layout.updateAutomaticRoute(for: train.id)
        if success {
            debug("Generated route is: \(route.steps)")
            return .processed
        } else {
            BTLogger.warning("Unable to find a suitable route for train \(train)")
            return .none
        }
    }
    
    private func debug(_ message: String) {
        BTLogger.debug(message)
    }

}
