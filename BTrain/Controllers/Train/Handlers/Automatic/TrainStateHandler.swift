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

final class TrainStateHandler: TrainAutomaticSchedulingHandler {
        
    var events: Set<TrainEvent> {
        [
            // React when the scheduling mode changes, which happens for example
            // when a train is started for the first time by request from the user.
            .schedulingChanged,
            
            // React when a train has moved to another block, because this means
            // that the train managed by this handler might be able to start or restart
            // as the blocks ahead might be free.
                .feedbackTriggered,
            
                .movedInsideBlock,
            .movedToNextBlock,
            .stateChanged,
            .restartTimerExpired
        ]
    }

    func process(layout: Layout, train: Train, route: Route, event: TrainEvent, controller: TrainControlling) throws -> TrainHandlerResult {
        guard var currentBlock = layout.currentBlock(train: train) else {
            return .none()
        }

        guard let trainInstance = currentBlock.train else {
            return .none()
        }

        var result: TrainHandlerResult = .none()
        switch event {
        case .feedbackTriggered:
            //            Upon feedback event:
            //            - Move train inside block (and reserve leading blocks)
            //            - Move train to next block (and reserve leading blocks)
            //            - Emergency stop if undetected feedback (at the layout controller level only)
            if try moveInsideBlock(layout: layout, train: train, block: currentBlock, direction: trainInstance.direction) {
                _ = try controller.reserveLeadBlocks(route: route, currentBlock: currentBlock)
                layout.adjustSpeedLimit(train)
                result = result.appending(.movedInsideBlock)
                
//                let r = try handleWagonsPushedByLocomotive(layout: layout, train: train, route: route, event: event, controller: controller)
//                result = result.appending(r)
            } else if try moveToNextBlock(layout: layout, train: train, block: currentBlock, direction: trainInstance.direction) {
                // TODO: handle nil here
                currentBlock = layout.currentBlock(train: train)!
                _ = try controller.reserveLeadBlocks(route: route, currentBlock: currentBlock)
                layout.adjustSpeedLimit(train)
                result = result.appending(.movedToNextBlock)
                
//                let r = try handleWagonsPushedByLocomotive(layout: layout, train: train, route: route, event: event, controller: controller)
//                result = result.appending(r)
            }

        case .schedulingChanged:
            if train.managedScheduling && train.state == .stopped {
                train.startRouteIndex = 0
                train.routeStepIndex = 0
                _ = try controller.reserveLeadBlocks(route: route, currentBlock: currentBlock)
            } else if train.unmanagedScheduling {
                try layout.reservation.removeLeadingBlocks(train: train)
            }

        case .stopRequested:
            break
        case .restartTimerExpired:
            // TODO: only do that when this event is about this train and not another train!
            train.startRouteIndex = train.routeStepIndex
            break
        case .turnoutChanged:
            break
        case .directionChanged:
            break
        case .speedChanged:
            break
        case .stateChanged:
            break
        case .movedInsideBlock:
            // If another train moves inside its block, it will update its reserved blocks
            // which might free up some blocks for this train to reserve.
//            _ = try controller.reserveLeadBlocks(route: route, currentBlock: currentBlock)
//            layout.adjustSpeedLimit(train)
            break
            
        case .movedToNextBlock:
            // If another train moves inside its block, it will update its reserved blocks
            // which might free up some blocks for this train to reserve.
//            _ = try controller.reserveLeadBlocks(route: route, currentBlock: currentBlock)
//            layout.adjustSpeedLimit(train)
            break

        }

        let context = Context(block: currentBlock, train: train, route: route, layout: layout)
        
        if (train.state == .stopped || train.state == .braking || train.state == .stopping) && canPotentiallyStart(context: context) {
            try layout.reservation.updateReservedBlocks(train: train)
        }
        
        if train.state != .running && isRunning(context: context) {
            BTLogger.router.debug("\(train, privacy: .public): start train for \(route.steps.debugDescription, privacy: .public)")
            // Setup the start route index of the train
            train.startRouteIndex = train.routeStepIndex
            
            train.stateChangeRequest = nil
            train.state = .running
            layout.setTrainSpeed(train, LayoutFactory.DefaultMaximumSpeed) { }
            result = result.appending(.stateChanged)
        }
        
        if train.state == .running && isBraking(context: context) {
            BTLogger.router.debug("\(train, privacy: .public): braking in \(currentBlock.name, privacy: .public) at position \(train.position), direction \(trainInstance.direction)")
            train.state = .braking
            layout.setTrainSpeed(train, currentBlock.brakingSpeed ?? LayoutFactory.DefaultBrakingSpeed) {}
            result = result.appending(.stateChanged)
        }

        if (train.state != .stopped && train.state != .stopping) && isStopping(context: context) {
            BTLogger.router.debug("\(train, privacy: .public): stopping in \(currentBlock.name, privacy: .public) at position \(train.position), direction \(trainInstance.direction)")
            try layout.reservation.removeLeadingBlocks(train: train)
            
            switch route.mode {
            case .fixed:
                if context.trainAtEndOfRoute {
                    _ = try controller.stop(completely: true)
                } else {
                    _ = try controller.stop(completely: false)
                    if layout.trainShouldStop(train: train, block: currentBlock) {
                        // If it is a station, reschedule a restart
                        reschedule(train: train, delay: context.waitingTime, controller: controller)
                    }
                }
                
            case .automatic:
                _ = try controller.stop(completely: false)
                if layout.trainShouldStop(train: train, block: currentBlock) {
                    // If it is a station, reschedule a restart
                    reschedule(train: train, delay: context.waitingTime, controller: controller)
                }

            case .automaticOnce(destination: let destination):
                assert(destination.blockId == currentBlock.id && destination.direction == context.trainDirectionInBlock)
                _ = try controller.stop(completely: true)
            }
            
            result = result.appending(.stateChanged)
        }
        
        layout.adjustSpeedLimit(train) // TODO: is that actually effective? as it works only when the train is running

        return result
    }
    
    func reschedule(train: Train, delay: TimeInterval, controller: TrainControlling) {
        BTLogger.router.debug("\(train, privacy: .public): schedule timer to restart train in \(delay, format: .fixed(precision: 1)) seconds")
        
        // The layout controller is going to schedule the appropriate timer given the `restartDelayTime` value
        train.timeUntilAutomaticRestart = delay
        controller.scheduleRestartTimer(train: train)
    }
    
    func moveInsideBlock(layout: Layout, train: Train, block: Block, direction: Direction) throws -> Bool {
        // Iterate over all the feedbacks of the block and react to those who are triggered (aka detected)
        for (index, feedback) in block.feedbacks.enumerated() {
            guard let f = layout.feedback(for: feedback.feedbackId), f.detected else {
                continue
            }
            
            let position = layout.newPosition(forTrain: train, enabledFeedbackIndex: index, direction: direction)
            if train.position != position {
                try layout.setTrainPosition(train, position)
                
                BTLogger.router.debug("\(train, privacy: .public): moved to position \(train.position) in \(block.name, privacy: .public), direction \(direction)")
                
                return true
            }
        }
        
        return false
    }
    
    func moveToNextBlock(layout: Layout, train: Train, block: Block, direction: Direction) throws -> Bool {
        // Find out what is the entry feedback for the next block
        let entryFeedback = try layout.entryFeedback(for: train)
        
        guard let entryFeedback = entryFeedback, entryFeedback.feedback.detected else {
            // The entry feedback is not yet detected, nothing more to do
            return false
        }
        
        guard let position = entryFeedback.block.indexOfTrain(forFeedback: entryFeedback.feedback.id, direction: entryFeedback.direction) else {
            throw LayoutError.feedbackNotFound(feedbackId: entryFeedback.feedback.id)
        }
         
        BTLogger.router.debug("\(train, privacy: .public): enters block \(entryFeedback.block, privacy: .public) at position \(position), direction \(entryFeedback.direction)")
                
        // Set the train to its new block. This method also takes care of updating the reserved blocks for the train itself
        // but also the leading blocks so the train can continue to move automatically.
        try layout.setTrainToBlock(train.id, entryFeedback.block.id, position: .custom(value: position), direction: entryFeedback.direction, routeIndex: train.routeStepIndex + 1)
        
        return true
    }
    
    // TODO: is that the best way to handle this? Can't this be included in the leading blocks computation?
    func handleWagonsPushedByLocomotive(layout: Layout, train: Train, route: Route, event: TrainEvent, controller: TrainControlling) throws -> TrainHandlerResult {
        guard train.speed.requestedKph > 0 else {
            return .none()
        }
        
        guard train.wagonsPushedByLocomotive else {
            return .none()
        }
                
        // Now determine the position of the head wagon given the next locomotive position
        guard let hwb = try TrainPositionFinder.headWagonBlockFor(train: train, startAtNextPosition: true, layout: layout) else {
            BTLogger.router.debug("\(train, privacy: .public): stop completely because there is no head wagon block found")
            return try controller.stop(completely: true)
        }
        
        print("*** \(train.name): \(hwb.name) - \(hwb.reserved)")
        if hwb.reserved != nil && hwb.reserved?.trainId != train.id {
            BTLogger.router.debug("\(train, privacy: .public): stop completely because the head wagon block is reserved for another train")
            return try controller.stop(completely: true)
        }
        
        return .none()
    }

//    Running if
//- all leading blocks reserved
//- waiting time at a station has expired
//- user started route
    // - the train has not reached the end of the route
    // - the block does not require the train to stop (ie station)
    func isRunning(context: Context) -> Bool {
        context.leadingBlocksReserved &&
        context.train.managedScheduling &&
        context.waitingTimeAtStationExpired &&
        context.trainAtEndOfRoute == false &&
        context.trainShouldStopInBlock == false
    }
    
    func canPotentiallyStart(context: Context) -> Bool {
        context.train.managedScheduling &&
        context.waitingTimeAtStationExpired &&
        context.trainAtEndOfRoute == false
    }

    // Braking if
    // - not all leading blocks reserved AND distance of reserved leading blocks is greater than the distance to stop the train
    // - OR reaching the "brake" feedback of a station
    // - OR the end of the route
    func isBraking(context: Context) -> Bool {
        context.trainShouldStopInBlock && context.brakingFeedbackTriggered
    }

    func isStopping(context: Context) -> Bool {
        context.trainShouldStopInBlock && context.stoppingFeedbackTriggered
    }

    struct Context {
        let block: Block
        let train: Train
        let route: Route
        let layout: Layout
        
        var trainDirectionInBlock: Direction? {
            guard let trainInstance = block.train else {
                return nil
            }
            
            let direction = trainInstance.direction
            return direction
        }
        
        var leadingBlocksReserved: Bool {
            train.leadingBlocks.count > 0
        }
        
        var trainShouldStopInBlock: Bool {
            leadingBlocksReserved == false ||
            trainAtEndOfRoute ||
            layout.trainShouldStop(train: train, block: block)
        }

        var brakingFeedbackTriggered: Bool {
            guard let trainDirectionInBlock = trainDirectionInBlock else {
                return false
            }

            guard let brakeFeedback = block.brakeFeedback(for: trainDirectionInBlock) else {
                return false
            }

            return isFeedbackTriggered(layout: layout, train: train, feedbackId: brakeFeedback)
        }
        
        var stoppingFeedbackTriggered: Bool {
            guard let trainDirectionInBlock = trainDirectionInBlock else {
                return false
            }

            guard let stopFeedback = block.stopFeedback(for: trainDirectionInBlock) else {
                return false
            }

            return isFeedbackTriggered(layout: layout, train: train, feedbackId: stopFeedback)
        }

        var trainAtEndOfRoute: Bool {
            train.routeStepIndex == route.lastStepIndex
        }
        
        var waitingTimeAtStationExpired: Bool {
            train.timeUntilAutomaticRestart <= 0
        }
        
        var waitingTime: TimeInterval {
            if let step = route.steps.element(at: train.routeStepIndex), case .block(let stepBlock) = step, let time = stepBlock.waitingTime {
                return time
            } else {
                // Use the block waiting time if the route itself has nothing specified
                return block.waitingTime
            }
        }
        
        // MARK: - Private
        
        private func isFeedbackTriggered(layout: Layout, train: Train, feedbackId: Identifier<Feedback>) -> Bool {

            for bf in block.feedbacks {
                guard let f = layout.feedback(for: bf.feedbackId) else {
                    continue
                }
                            
                if feedbackId == f.id && f.detected {
                    return true
                }
            }
            return false
        }


    }

}
