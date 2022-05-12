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
import OrderedCollections

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
    var resultingEvents = OrderedSet<TrainEvent>()
    
    var trainAtEndOfRoute: Bool {
        train.routeStepIndex == route.lastStepIndex
    }
    
    var destination: Destination? {
        if case .automaticOnce(let destination) = route.mode {
            return destination
        } else {
            return nil
        }
    }
    
    var leadingBlocksReserved: Bool {
        train.leadingBlocks.count > 0
    }
    
    var trainShouldStopInBlock: Bool {
        leadingBlocksReserved == false ||
        trainAtEndOfRoute ||
        layout.trainShouldStop(route: route, train: train, block: currentBlock) ||
        currentBlock.id == destination?.blockId
    }
    
    var brakingFeedbackTriggered: Bool {
        guard let brakeFeedback = currentBlock.brakeFeedback(for: trainInstance.direction) else {
            return false
        }
        
        return isFeedbackTriggered(layout: layout, train: train, feedbackId: brakeFeedback)
    }
    
    var stoppingFeedbackTriggered: Bool {
        guard let stopFeedback = currentBlock.stopFeedback(for: trainInstance.direction) else {
            return false
        }
        
        return isFeedbackTriggered(layout: layout, train: train, feedbackId: stopFeedback)
    }
    
    var waitingTimeAtStationExpired: Bool {
        train.timeUntilAutomaticRestart <= 0
    }
    
    var waitingTime: TimeInterval {
        if let step = route.steps.element(at: train.routeStepIndex), case .block(let stepBlock) = step, let time = stepBlock.waitingTime {
            return time
        } else {
            // Use the block waiting time if the route itself has nothing specified
            return currentBlock.waitingTime
        }
    }
    
    /// This method is invoked when an event machings ``TrainAutomaticSchedulingHandler/events`` is triggered.
    ///
    /// - Parameters:
    ///   - layout: the layout
    ///   - train: the train
    ///   - route: the route
    ///   - event: the event that triggered this method invocation
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
    
    func process() throws -> TrainHandlerResult {
        try handleEvent()
        
        try handleTrainStart()
        
        handleTrainBrake()
        
        try handleTrainStop()
        
        layout.adjustSpeedLimit(train)
        
        return .init(events: Array(resultingEvents))
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
                train.startRouteIndex = 0
                train.routeStepIndex = 0
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
            if train.position != position {
                try layout.setTrainPosition(train, position)
                
                BTLogger.router.debug("\(self.train, privacy: .public): moved to position \(self.train.position) in \(self.currentBlock.name, privacy: .public), direction \(self.trainInstance.direction)")
                
                try reserveLeadingBlocks()
                
                return true
            }
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
        
        guard waitingTimeAtStationExpired else {
            return
        }
        
        switch route.mode {
        case .fixed:
            if trainAtEndOfRoute == false {
                try reserveLeadingBlocks()
            }
            
        case .automatic:
            try reserveLeadingBlocks()
            
        case .automaticOnce(destination: _):
            if trainAtEndOfRoute == false {
                try reserveLeadingBlocks()
            }
        }
        
        if leadingBlocksReserved && trainAtEndOfRoute == false && trainShouldStopInBlock == false {
            BTLogger.router.debug("\(self.train, privacy: .public): start train for \(self.route.steps.debugDescription, privacy: .public)")
            // Setup the start route index of the train
            train.startRouteIndex = train.routeStepIndex
            
            train.state = .running
            layout.setTrainSpeed(train, LayoutFactory.DefaultMaximumSpeed) { }
            resultingEvents.append(.stateChanged)
        }
    }
    
    func handleTrainBrake() {
        guard train.state == .running && trainShouldStopInBlock && brakingFeedbackTriggered else {
            return
        }
        
        BTLogger.router.debug("\(self.train, privacy: .public): braking in \(self.currentBlock.name, privacy: .public) at position \(self.train.position), direction \(self.trainInstance.direction)")
        train.state = .braking
        layout.setTrainSpeed(train, currentBlock.brakingSpeed ?? LayoutFactory.DefaultBrakingSpeed) {}
        resultingEvents.append(.stateChanged)
    }
    
    func handleTrainStop() throws {
        guard train.state != .stopped && train.state != .stopping && trainShouldStopInBlock && stoppingFeedbackTriggered else {
            return
        }
        
        BTLogger.router.debug("\(self.train, privacy: .public): stopping in \(self.currentBlock.name, privacy: .public) at position \(self.train.position), direction \(self.trainInstance.direction)")
        try layout.reservation.removeLeadingBlocks(train: train)
        
        switch route.mode {
        case .fixed:
            let trainShouldStop = layout.trainShouldStop(route: route, train: train, block: currentBlock)
            let stopCompletely = (trainShouldStop && train.managedFinishingScheduling) || trainAtEndOfRoute
            
            _ = try controller.stop(completely: stopCompletely)
            
            if trainShouldStop && stopCompletely == false {
                // If it is a station, reschedule a restart
                reschedule(train: train, delay: waitingTime, controller: controller)
            }
            
        case .automatic:
            let trainShouldStop = layout.trainShouldStop(route: route, train: train, block: currentBlock)
            let stopCompletely = trainShouldStop && train.managedFinishingScheduling
            
            _ = try controller.stop(completely: stopCompletely)
            
            if trainShouldStop && stopCompletely == false {
                // If it is a station, reschedule a restart
                reschedule(train: train, delay: waitingTime, controller: controller)
            }
            
        case .automaticOnce(destination: let destination):
            // Double-check that the train is moving in the direction specified by the destination, if specified.
            // This should never fail.
            if let direction = destination.direction, currentBlock.train?.direction != direction {
                throw LayoutError.destinationDirectionMismatch(currentBlock: currentBlock, destination: destination)
            }
            _ = try controller.stop(completely: true)
        }
        
        resultingEvents.append(.stateChanged)
    }
    
    func reschedule(train: Train, delay: TimeInterval, controller: TrainControlling) {
        BTLogger.router.debug("\(train, privacy: .public): schedule timer to restart train in \(delay, format: .fixed(precision: 1)) seconds")
        
        // The layout controller is going to schedule the appropriate timer given the `restartDelayTime` value
        train.timeUntilAutomaticRestart = delay
        controller.scheduleRestartTimer(train: train)
    }
        
    func reserveLeadingBlocks() throws {
        if try layout.reservation.updateReservedBlocks(train: train) {
            resultingEvents.append(.stateChanged)
            return
        }
        
        guard route.automatic else {
            return
        }
        
        if layout.trainShouldStop(route: route, train: train, block: currentBlock) {
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
