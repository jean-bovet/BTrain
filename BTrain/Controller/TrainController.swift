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
    func scheduleRestartTimer(train: Train)
}

// This class manages a single train in the layout, by starting and stopping it,
// managing the monitoring when it transition from one block to another, etc.
final class TrainController {
    
    // Most method in this class returns a result
    // that indicates if that method has done something
    // or not. This is useful information that will help
    // the LayoutController to re-run the TrainController
    // in case there are any changes to be applied.
    enum Result {
        case none
        case processed
    }
    
    let layout: Layout
    let train: Train
    weak var delegate: TrainControllerDelegate?
        
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
        // Handle automatic scheduling, otherwise handle manual operations
        guard train.automaticScheduling else {
            return try handleManualOperation()
        }

        // Stop the train if there is no route associated with it
        guard let route = layout.route(for: train.routeId, trainId: train.id) else {
            return try stop()
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

        // Do not start the train if there is still time for the train until it has to restart
        guard train.timeUntilAutomaticRestart == 0 else {
            return .none
        }
        
        // If the train was scheduled to finish, make sure it is finished
        if train.automaticFinishingScheduling {
            // The train is already stopped but make sure to update the scheduling status
            try layout.stopCompletely(train.id)
            return .processed
        }
        
        let nextBlock = layout.nextBlock(train: train)
        
        // Update the automatic route if the next block is not defined and if the automatic route
        // does not have a destinationBlock.
        if nextBlock == nil && route.automatic && route.automaticMode == .endless {
            debug("Generating a new route for \(train) at block \(currentBlock.name) with mode \(route.automaticMode) because the next block is not defined")
            return try updateAutomaticRoute(for: train.id)
        }
                
        // Try to reserve the next blocks and if successfull, then start the train
        if try layout.updateReservedBlocks(train: train, forceReserveLeadingBlocks: true) {
            debug("Start train \(train.name) because the next blocks could be reserved")
            train.startRouteIndex = train.routeStepIndex
            train.state = .running
            try layout.setTrainSpeed(train, LayoutFactory.DefaultSpeed)
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
        guard train.routeStepIndex != train.startRouteIndex else {
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
        guard train.routeStepIndex != train.startRouteIndex else {
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
    
    // This method takes care to trigger a stop of the train located in
    // the specified `block`, depending on the block characteristics.
    // For now, only "station" blocks make the train stop.
    private func handleTrainStopByBlock(route: Route, block: Block) -> Result {
        guard layout.trainShouldStop(train: train, block: block) else {
            return .none
        }
                
        if train.automaticFinishingScheduling {
            debug("Stopping completely \(train) because it has reached a station and was finishing the route")
            stopTrigger = StopTrigger.completeStop()
            return .processed
        } else {
            let delay = waitingTime(route: route, train: train, block: block)
            stopTrigger = StopTrigger.stopAndRestart(after: delay)
            return .processed
        }
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
                        train.timeUntilAutomaticRestart = stopTrigger.restartDelay
                        delegate?.scheduleRestartTimer(train: train)
                    }
                }
            }
        }
        return result
    }
    
    func handleTrainMove() throws -> Result {
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
            
            let position = layout.newPosition(forTrain: train, enabledFeedbackIndex: index, direction: direction)
            if train.position != position {
                try layout.setTrainPosition(train, position)
                debug("Train \(train) moved to position \(train.position) in \(currentBlock.name), direction \(direction)")
                result = .processed
            }
                        
        }
        
        return result
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
        let (entryFeedback, direction) = try layout.entryFeedback(from: currentBlock, to: nextBlock)
        
        guard let entryFeedback = entryFeedback, entryFeedback.detected else {
            // The entry feedback is not yet detected, nothing more to do
            return .none
        }
        
        guard let position = nextBlock.indexOfTrain(forFeedback: entryFeedback.id, direction: direction) else {
            throw LayoutError.feedbackNotFound(feedbackId: entryFeedback.id)
        }
                
        debug("Train \(train) enters block \(nextBlock) at position \(position), direction \(direction)")
                
        // Set the train to its new block. This method will also free up all the other blocks from the train, expect
        // the blocks trailing the train depending on its length and the length of the blocks.
        // Note: we will reserve again the leading blocks below in `reserveNextBlocks`.
        try layout.setTrainToBlock(train.id, nextBlock.id, position: .custom(value: position), direction: direction)
        
        // Increment the train route index
        try layout.setTrainRouteStepIndex(train, train.routeStepIndex + 1)
                                
        // Handle any route-specific stop now that the train has moved to a new block
        if route.automatic {
            _ = try handleAutomaticRouteStop(route: route)
        } else {
            _ = try handleManualRouteStop(route: route)
        }
        
        // If the train is not stopping in this block, reserve the block(s) ahead.
        if stopTrigger == nil {
            if try layout.updateReservedBlocks(train: train) == false {
                // If it is not possible, then stop the train in this block
                debug("Train \(train) will stop here (\(nextBlock)) because the next block(s) cannot be reserved")
                stopTrigger = StopTrigger.temporaryStop()
            }
        }

        return .processed
    }
        
    func stop(completely: Bool = false) throws -> Result {
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
    
    func debug(_ message: String) {
        BTLogger.debug(message)
    }

}
