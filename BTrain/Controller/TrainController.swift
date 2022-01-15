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

        // Stop the train if the route is disabled
        guard route.enabled else {
            return try stop()
        }

        var result: Result = .none
        
        if try handleTrainStart() == .processed {
            result = .processed
        }

        if try handleTrainMove() == .processed {
            result = .processed
        }
        
        if try handleTrainAutomaticRouteUpdate(route: route) == .processed {
            result = .processed
        }
        
        if try handleTrainStop(route: route) == .processed {
            result = .processed
        }

        if try handleTrainMoveToNextBlock() == .processed {
            result = .processed
        }
        
        if try handleTrainStop(route: route) == .processed {
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

        let nextBlock = layout.nextBlock(train: train)
        if nextBlock == nil && route.automatic {
            // If the route is automatic and the next block is nil, let's update the route
            BTLogger.debug("Generating a new route for \(train) at block \(currentBlock.name) with destination \(String(describing: route.destinationBlock)) because the next block is not defined")
            try updateAutomaticRoute(for: train.id, toBlockId: route.destinationBlock)
        }
        
        // Start train if next block is free and reserve it
        if let nextBlock = nextBlock, (nextBlock.reserved == nil || nextBlock.reserved == currentBlock.reserved) && nextBlock.train == nil && nextBlock.enabled {
            do {
                try layout.reserve(train: train.id, fromBlock: currentBlock.id, toBlock: nextBlock.id, direction: currentBlock.train!.direction)
                BTLogger.debug("Start train \(train) because the next block \(nextBlock) is free or reserved for this train", layout, train)
                startRouteIndex = train.routeIndex
                try layout.setTrain(train, speed: LayoutFactory.DefaultSpeed)
                return .processed
            } catch {
                BTLogger.debug("Cannot start train \(train) because \(error)", layout, train)
            }
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
        BTLogger.debug("Generating a new route for \(train.name) at block \(currentBlock.name) because the next block \(nextBlock.name) is occupied or disabled")

        // Update the automatic route using any previously defined destination block
        try updateAutomaticRoute(for: train.id, toBlockId: route.destinationBlock)
                        
        return .processed
    }
    
    private func handleTrainStop(route: Route) throws -> Result {
        guard train.speed.kph > 0 else {
            return .none
        }
        
        guard let currentBlock = layout.currentBlock(train: train) else {
            return .none
        }

        let atEndOfBlock = layout.atEndOfBlock(train: train)
        
        // Stop the train if the current block is a station, the train is located at the end of the block
        // and the train is running (this is to ensure we don't stop a train that just started from the station).
        // Stop the train when it reaches a station block, given that this block is not the one where the train
        // started - to avoid stopping a train that is starting from a station block (while still in that block).
        if currentBlock.category == .station && atEndOfBlock && train.routeIndex != startRouteIndex {
            BTLogger.debug("Stop train \(train) because the current block \(currentBlock) is a station", layout, train)
            
            // If the route is automatic, stop the train for a specific period of time and then restart it.
            if route.automatic {
                BTLogger.debug("Schedule timer to restart train \(train.name) in \(route.stationWaitDuration) seconds")
                
                // The layout controller is going to schedule the appropriate timer given the `restartDelayTime` value
                if let ti = currentBlock.train {
                    ti.restartDelayTime = route.stationWaitDuration
                    delegate?.scheduleRestartTimer(trainInstance: ti)
                }
            }
            return try stop()
        }

        guard let nextBlock = layout.nextBlock(train: train) else {
            // Stop the train if there is no next block
            if atEndOfBlock {
                BTLogger.debug("Stop train \(train) because there is no next block (after \(currentBlock))", layout, train)
                return try stop()
            } else {
                return .none
            }
        }
        
        // Stop if the next block is occupied
        if nextBlock.train != nil && atEndOfBlock {
            BTLogger.debug("Stop train \(train) train because the next block is occupied", layout, train)
            return try stop()
        }

        // Stop if the next block is reserved for another train
        // Note: only test the train ID because the direction can actually be different; for example, exiting
        // the current block in the "next" direction but traveling inside the next block with the "previous" direction.
        if let reserved = nextBlock.reserved, reserved != currentBlock.reserved && atEndOfBlock {
            BTLogger.debug("Stop train \(train) because the next block is reserved for another train \(reserved)", layout, train)
            return try stop()
        }
        
        // Stop if the next block is not reserved
        if nextBlock.reserved == nil && atEndOfBlock {
            BTLogger.debug("Stop train \(train) because the next block is not reserved", layout, train)
            return try stop()
        }

        // Stop if the next block is disabled
        if !nextBlock.enabled && atEndOfBlock {
            BTLogger.debug("Stop train \(train) because the next block is disabled", layout, train)
            return try stop()
        }

        if currentBlock.reserved == nil {
            BTLogger.debug("Stop train \(train) because the current block is not reserved", layout, train)
            return try stop()
        }
        
        return .none
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
        
        var result: Result = .none
        for (index, feedback) in currentBlock.feedbacks.enumerated() {
            guard let f = layout.feedback(for: feedback.feedbackId), f.detected else {
                continue
            }
            
            let position = newPosition(forTrain: train, enabledFeedbackIndex: index, direction: trainInstance.direction)
            if train.position != position {
                try layout.setTrain(train, toPosition: position)
                BTLogger.debug("Train moved to position \(train.position), direction \(trainInstance.direction)", layout, train)
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
    
    private func handleTrainMoveToNextBlock() throws -> Result {
        guard train.speed.kph > 0 else {
            return .none
        }
        
        guard layout.shouldHandleTrainMoveToNextBlock(train: train) else {
            return .none
        }
        
        guard let currentBlock = layout.currentBlock(train: train) else {
            return .none
        }

        guard let nextBlock = layout.nextBlock(train: train) else {
            return .none
        }

        // Get the first feedback that the train will hit upon entering the block,
        // which depends on the direction of travel within the block itself.
        let (firstFeedback, naturalDirection) = try layout.feedbackTriggeringTransition(from: currentBlock, to: nextBlock)
        
        guard let firstFeedback = firstFeedback, firstFeedback.detected else {
            // The first feedback is not yet detected, nothing more to do
            return .none
        }
        
        // The next block now has the train
        let direction: Direction
        let position: Int
        if naturalDirection {
            direction = .next
            position = 1
        } else {
            // Entering the next block from the "next" side, meaning the train
            // is running backwards inside the block from the block natural direction.
            direction = .previous
            position = nextBlock.feedbacks.count - 1
        }
        
        BTLogger.debug("Train \(train) enters block \(nextBlock) at position \(position), direction \(direction)", layout, train)

        // Asks the layout to move the train to the next block
        try layout.setTrain(train.id, toBlock: nextBlock.id, position: .custom(value: position), direction: direction)
        
        try layout.setTrain(train, routeIndex: train.routeIndex + 1)
                
        // Reserve the block ahead if possible
        _ = tryReserveNextBlocks(direction: direction)
        
        return .processed
    }
    
    private func tryReserveNextBlocks(direction: Direction) -> Result {
        guard let currentBlock = layout.currentBlock(train: train) else {
            return .none
        }
        
        guard let nextBlock = layout.nextBlock(train: train) else {
            return .none
        }
        
        guard nextBlock.reserved == nil else {
            return .none
        }
        
        guard nextBlock.enabled else {
            return .none
        }
        
        do {
            try layout.reserve(train: train.id, fromBlock: currentBlock.id, toBlock: nextBlock.id, direction: direction)
            BTLogger.debug("Next block \(nextBlock) is reserved", layout, train)
            return .processed
        } catch {
            BTLogger.debug("Cannot reserve next blocks because \(error)", layout, train)
            return .none
        }
    }
    
    private func stop() throws -> Result {
        guard train.speed.kph > 0 else {
            return .none
        }
        
        BTLogger.debug("Stop train \(train)", layout, train)
        
        try layout.stopTrain(train)
        
        return .processed
    }
    
    // This method is called by the LayoutController when a train that was paused must be restarted.
    // This happens after the timer associated with the train expired in the LayoutController.
    // This method actually does not restart the train per say but update the automatic route in order
    // to have a valid route to follow. In a later cycle, the TrainController will start the train
    // if the conditions are right (next block free, route enabled, etc).
    func restartTrain() throws {
        guard let routeId = train.routeId else {
            throw LayoutError.trainNotAssignedToARoute(train: train)
        }
        
        guard let route = layout.route(for: routeId, trainId: train.id) else {
            throw LayoutError.routeNotFound(routeId: routeId)
        }
        
        guard route.automatic else {
            BTLogger.debug("Cannot restart train \(train) because route \(route.name) is not automatic")
            return
        }
        
        BTLogger.debug("Re-starting train \(train) by updating the automatic route", layout, train)
        // Note: we are generating a new route to any station block
        try updateAutomaticRoute(for: train.id, toBlockId: nil)
    }
    
    private func updateAutomaticRoute(for trainId: Identifier<Train>, toBlockId: Identifier<Block>?) throws {
        let (success, route) = try layout.updateAutomaticRoute(for: train.id, toBlockId: toBlockId)
        if success {
            BTLogger.debug("Generated route is: \(route.steps)", layout, train)
        } else {
            BTLogger.debug("Unable to find a suitable route for train \(train)", layout, train)
        }
    }
    
}
