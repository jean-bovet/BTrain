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

/// Manages the operation of a single train in the layout.
///
/// When BTrain manages a train, it must ensure the train starts, stops
/// and brakes appropriately to avoid collision with other trains and respect
/// the constraints of the layout while following the indication of the route
/// assigned to the train. BTrain does this by responding to events from the layout,
/// such as ``TrainEvent/feedbackTriggered`` when a feedback is triggered
/// in the layout indicating a train is passing over the feedback.
final class TrainHandlerManaged {
    
    let layout: Layout
    let route: Route
    let train: Train
    let event: TrainEvent
    let controller: TrainControlling
    
    var currentBlock: Block
    var trainInstance: TrainInstance
    let resultingEvents = TrainHandlerResult()
    
    /// Returns true if the train is at the end of the route
    var trainAtEndOfRoute: Bool {
        train.routeStepIndex == route.lastStepIndex
    }
    
    /// Returns true if the train should stop in the current block
    ///
    /// The following reasons will cause a train to stop:
    /// - There are no leading blocks reserved or there are leading blocks reserved but not yet settled.
    /// - The train is at the end of the route
    /// - The train has reached either a station block or a block that is the destination of the route
    var trainShouldStop: Bool {
        train.leading.reservedAndSettled == false ||
        trainAtEndOfRoute ||
        layout.hasTrainReachedStationOrDestination(route, train, currentBlock)
    }
    
    /// Returns true if the block feedback assigned to brake the train is triggered
    var brakingFeedbackTriggered: Bool {
        guard let brakeFeedback = currentBlock.brakeFeedback(for: trainInstance.direction) else {
            return false
        }
        
        return isFeedbackTriggered(layout: layout, train: train, feedbackId: brakeFeedback)
    }
    
    /// Returns true if the block feedback assigned to stop the train is triggered
    var stoppingFeedbackTriggered: Bool {
        guard let stopFeedback = currentBlock.stopFeedback(for: trainInstance.direction) else {
            return false
        }
        
        return isFeedbackTriggered(layout: layout, train: train, feedbackId: stopFeedback)
    }
    
    /// Returns the time the train needs to wait in the current block
    var waitingTime: TimeInterval {
        if let step = route.steps.element(at: train.routeStepIndex),
           case .block(let stepBlock) = step,
           let time = stepBlock.waitingTime {
            return time
        } else {
            // Use the block waiting time if the route itself has nothing specified
            return currentBlock.waitingTime
        }
    }
    
    /// This method is invoked when a ``TrainEvent`` is triggered in the layout.
    ///
    /// - Parameters:
    ///   - layout: the layout
    ///   - train: the train
    ///   - route: the route
    ///   - event: the event that triggered this method
    ///   - controller: the train controller
    /// - Returns: returns the result of the process, which can include one or more follow up events
    static func process(layout: Layout, route: Route, train: Train, event: TrainEvent, controller: TrainControlling) throws -> TrainHandlerResult {
        guard let currentBlock = layout.currentBlock(train: train) else {
            return .none()
        }
        
        guard let trainInstance = currentBlock.train else {
            return .none()
        }
        
        let handler = TrainHandlerManaged(layout: layout, route: route, train: train, event: event, controller: controller, currentBlock: currentBlock, trainInstance: trainInstance)
        return try handler.process()
    }
    
    private init(layout: Layout, route: Route, train: Train, event: TrainEvent, controller: TrainControlling, currentBlock: Block, trainInstance: TrainInstance) {
        self.layout = layout
        self.route = route
        self.train = train
        self.event = event
        self.controller = controller
        self.currentBlock = currentBlock
        self.trainInstance = trainInstance
    }
    
    private func process() throws -> TrainHandlerResult {
        try handleEvent()
        
        try handleTrainStart()
        
        handleTrainBrake()
        
        try handleTrainStop()
        
        layout.adjustSpeedLimit(train)
        
        return resultingEvents
    }
    
    func handleEvent() throws {
        switch event {
        case .feedbackTriggered:
            if try moveInsideBlock() {
                resultingEvents.append(.movedInsideBlock)
            } else if try moveToNextBlock() {
                resultingEvents.append(.movedToNextBlock)
            }
            
        case .schedulingChanged:
            if train.managedScheduling && train.state == .stopped {
                // Note: routeStepIndex is setup by the start() method in the Layout, which
                // can set its value to something > 0 if the train is somewhere along the route.
                train.startRouteIndex = train.routeStepIndex
                try reserveLeadingBlocks()
            } else if train.unmanagedScheduling {
                try layout.reservation.removeLeadingBlocks(train: train)
            }
            
        case .restartTimerExpired(let train):
            // Only restart the train if it is not marked as "finishing", meaning that the user
            // want the train to finish its route after stopping in a station block.
            if train.managedFinishingScheduling == false && train == self.train {
                train.startRouteIndex = train.routeStepIndex
            }
            
        case .turnoutChanged:
            break
        case .directionChanged:
            break
        case .speedChanged:
            break
        case .stateChanged:
            break
        case .movedInsideBlock:
            break
        case .movedToNextBlock:
            break
        }
    }
    
    func moveInsideBlock() throws -> Bool {
        // Iterate over all the feedbacks of the block and react to those who are triggered (aka detected)
        for (index, feedback) in currentBlock.feedbacks.enumerated() {
            guard let f = layout.feedback(for: feedback.feedbackId), f.detected else {
                continue
            }
            
            let position = layout.newPosition(forTrain: train, enabledFeedbackIndex: index, direction: trainInstance.direction)
            
            guard train.position != position else {
                continue
            }
            
            try layout.setTrainPosition(train, position)
            
            BTLogger.router.debug("\(self.train, privacy: .public): moved to position \(self.train.position) in \(self.currentBlock.name, privacy: .public), direction \(self.trainInstance.direction)")
            
            try reserveLeadingBlocks()
            
            return true
        }
        
        return false
    }
    
    func moveToNextBlock() throws -> Bool {
        // Find out what is the entry feedback for the next block
        let entryFeedback = try layout.entryFeedback(for: train)
        
        guard let entryFeedback = entryFeedback, entryFeedback.feedback.detected else {
            // The entry feedback is not yet detected, nothing more to do
            return false
        }
        
        guard let position = entryFeedback.block.indexOfTrain(forFeedback: entryFeedback.feedback.id, direction: entryFeedback.direction) else {
            throw LayoutError.feedbackNotFound(feedbackId: entryFeedback.feedback.id)
        }
        
        BTLogger.router.debug("\(self.train, privacy: .public): enters block \(entryFeedback.block, privacy: .public) at position \(position), direction \(entryFeedback.direction)")
        
        // Set the train to its new block. This method also takes care of updating the reserved blocks for the train itself
        // but also the leading blocks so the train can continue to move automatically.
        try layout.setTrainToBlock(train.id, entryFeedback.block.id, position: .custom(value: position), direction: entryFeedback.direction, routeIndex: train.routeStepIndex + 1)
        
        guard let newBlock = layout.block(for: entryFeedback.block.id) else {
            throw LayoutError.blockNotFound(blockId: entryFeedback.block.id)
        }
        
        currentBlock = newBlock
        
        guard let newTrainInstance = newBlock.train else {
            throw LayoutError.trainNotFoundInBlock(blockId: newBlock.id)
        }
        
        trainInstance = newTrainInstance
        
        try reserveLeadingBlocks()
        
        return true
    }
    
    func handleTrainStart() throws {
        guard train.state != .running else {
            return
        }
        
        guard train.managedScheduling else {
            return
        }
        
        guard train.timeUntilAutomaticRestart <= 0 else {
            return
        }
        
        if trainAtEndOfRoute == false || route.mode == .automatic {
            try reserveLeadingBlocks()
        }
        
        if train.leading.reservedAndSettled && trainAtEndOfRoute == false && trainShouldStop == false {
            BTLogger.router.debug("\(self.train, privacy: .public): start train for \(self.route.steps.debugDescription, privacy: .public)")
            // Setup the start route index of the train
            train.startRouteIndex = train.routeStepIndex
            
            train.state = .running
            layout.setTrainSpeed(train, LayoutFactory.DefaultMaximumSpeed) { }
            resultingEvents.append(.stateChanged)
        }
    }
    
    func handleTrainBrake() {
        guard train.state == .running && trainShouldStop && brakingFeedbackTriggered else {
            return
        }
        
        BTLogger.router.debug("\(self.train, privacy: .public): braking in \(self.currentBlock.name, privacy: .public) at position \(self.train.position), direction \(self.trainInstance.direction)")
        train.state = .braking
        layout.setTrainSpeed(train, currentBlock.brakingSpeed ?? LayoutFactory.DefaultBrakingSpeed) {}
        resultingEvents.append(.stateChanged)
    }
    
    func handleTrainStop() throws {
        guard train.state != .stopped && train.state != .stopping && trainShouldStop && stoppingFeedbackTriggered else {
            return
        }
        
        BTLogger.router.debug("\(self.train, privacy: .public): stopping in \(self.currentBlock.name, privacy: .public) at position \(self.train.position), direction \(self.trainInstance.direction)")
        try layout.reservation.removeLeadingBlocks(train: train)
        
        switch route.mode {
        case .fixed:
            let reachedStationOrDestination = layout.hasTrainReachedStationOrDestination(route, train, currentBlock)
            let stopCompletely = (reachedStationOrDestination && train.managedFinishingScheduling) || trainAtEndOfRoute
            
            _ = try controller.stop(completely: stopCompletely)
            
            if reachedStationOrDestination && stopCompletely == false {
                reschedule(train: train, delay: waitingTime, controller: controller)
            }
            
        case .automatic:
            let reachedStationOrDestination = layout.hasTrainReachedStationOrDestination(route, train, currentBlock)
            let stopCompletely = reachedStationOrDestination && train.managedFinishingScheduling
            
            _ = try controller.stop(completely: stopCompletely)
            
            if reachedStationOrDestination && stopCompletely == false {
                reschedule(train: train, delay: waitingTime, controller: controller)
            }
            
        case .automaticOnce(destination: _):
            _ = try controller.stop(completely: true)
        }
        
        resultingEvents.append(.stateChanged)
    }
    
    func reschedule(train: Train, delay: TimeInterval, controller: TrainControlling) {
        BTLogger.router.debug("\(train, privacy: .public): schedule timer to restart train in \(delay, format: .fixed(precision: 1)) seconds")
        
        train.timeUntilAutomaticRestart = delay
        controller.scheduleRestartTimer(train: train)
    }
        
    func reserveLeadingBlocks() throws {
        // Do not reserve leading blocks if there are still settling,
        // that is, some turnout are not yet fully settled.
        guard train.leading.emptyOrSettled else {
            return
        }

        switch route.mode {
        case .fixed:
            if try layout.reservation.updateReservedBlocks(train: train) {
                resultingEvents.append(.stateChanged)
                return
            }

        case .automatic, .automaticOnce(destination: _):
            if try layout.reservation.updateReservedBlocks(train: train) {
                resultingEvents.append(.stateChanged)
                return
            }

            if layout.hasTrainReachedStationOrDestination(route, train, currentBlock) {
                return
            }
            
            BTLogger.router.debug("\(self.train, privacy: .public): generating a new route at \(self.currentBlock.name, privacy: .public) because the leading blocks could not be reserved for \(self.route.steps.debugDescription, privacy: .public)")
            
            // Update the automatic route
            if try updateAutomaticRoute(for: train, layout: layout) {
                // And try to reserve the lead blocks again
                if try layout.reservation.updateReservedBlocks(train: train) {
                    resultingEvents.append(.stateChanged)
                }
            }
        }
    }
    
    private func updateAutomaticRoute(for train: Train, layout: Layout) throws -> Bool {
        let (success, route) = try layout.automaticRouting.updateAutomaticRoute(for: train.id)
        if success {
            BTLogger.router.debug("\(train, privacy: .public): generated route is \(route.steps.debugDescription, privacy: .public)")
            return true
        } else {
            BTLogger.router.warning("\(train, privacy: .public): unable to find a suitable route")
            return false
        }
    }
    
    private func isFeedbackTriggered(layout: Layout, train: Train, feedbackId: Identifier<Feedback>) -> Bool {
        for bf in currentBlock.feedbacks {
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
