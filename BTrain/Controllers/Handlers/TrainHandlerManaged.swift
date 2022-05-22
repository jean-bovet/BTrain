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

/**
 Manages the operation of a single train in the layout.
 
 When BTrain manages a train, it must ensure the train starts, stops
 and brakes appropriately to avoid collision with other trains and respect
 the constraints of the layout while following the indication of the route
 assigned to the train. BTrain does this by responding to events from the layout,
 such as ``TrainEvent/feedbackTriggered`` when a feedback is triggered
 in the layout indicating a train is passing over the feedback.
 
 There are two kinds of routes:
 
 *Manual Route*
 
 A manual route is created manually by the user and does not change when the train is running. This controller ensures the train follows the manual route
 and stops the train if the block(s) ahead cannot be reserved. The train is restarted when the block(s) ahead can be reserved again.
 
 *Automatic Route*
 
 An automatic route is created and managed automatically by BTrain:
 - An automatic route is created each time a train starts
 - An automatic route is updated when the train moves into a new block and the block(s) ahead cannot be reserved
 
 An automatic route is created using the following rules:
 - If there is a destination defined (ie the user as specified to which block the train should move to), the automatic route is created using the shortest path algorithm.
 - If there are no destination specified, BTrain finds a random route from the train position until a station block is found. During the search, block or turnout that
 should be avoided will be ignored. However, elements reserved for other trains will be taken into account because the reservations
 will change as the trains move in the layout.
 */
final class TrainHandlerManaged {
    
    let layout: Layout
    let reservation: LayoutReservation
    let executor: LayoutController
    let route: Route
    let train: Train
    let event: TrainEvent
    
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
    /// - There are no leading blocks reserved
    /// - There are leading blocks but there is not enough distance to brake safely the train
    /// - The train is at the end of the route
    /// - The train has reached either a station block or a block that is the destination of the route
    /// - The train has been requested to stop by the user (scheduling == .stopManaged)
    var trainShouldStop: Bool {
        train.leading.isEmpty ||
        reservation.isBrakingDistanceRespected(train: train, speed: train.speed.actualKph) == false ||
        trainAtEndOfRoute ||
        layout.hasTrainReachedStationOrDestination(route, train, currentBlock) ||
        train.scheduling == .stopManaged
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
    /// - Returns: returns the result of the process, which can include one or more follow up events
    static func process(layout: Layout, reservation: LayoutReservation, executor: LayoutController, route: Route, train: Train, event: TrainEvent) throws -> TrainHandlerResult {
        guard let currentBlock = layout.currentBlock(train: train) else {
            return .none()
        }
        
        guard let trainInstance = currentBlock.train else {
            return .none()
        }
        
        let handler = TrainHandlerManaged(layout: layout, reservation: reservation, executor: executor, route: route, train: train, event: event, currentBlock: currentBlock, trainInstance: trainInstance)
        return try handler.process()
    }
    
    private init(layout: Layout, reservation: LayoutReservation, executor: LayoutController, route: Route, train: Train, event: TrainEvent, currentBlock: Block, trainInstance: TrainInstance) {
        self.layout = layout
        self.reservation = reservation
        self.executor = executor
        self.route = route
        self.train = train
        self.event = event
        self.currentBlock = currentBlock
        self.trainInstance = trainInstance
    }
    
    private func process() throws -> TrainHandlerResult {
        try handleEvent()
        
        try handleTrainStart()
        
        handleTrainBrake()
        
        try handleTrainStop()
        
        adjustSpeedLimit(train)
        
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
            switch train.scheduling {
            case .unmanaged:
                try reservation.removeLeadingBlocks(train: train)

            case .managed:
                if train.state == .stopped {
                    // Note: routeStepIndex is setup by the start() method in the Layout, which
                    // can set its value to something > 0 if the train is somewhere along the route.
                    train.startRouteIndex = train.routeStepIndex
                    try reserveLeadingBlocks() // TODO: seems unnecessary as handleTrainStart will do it anyway
                }

            case .stopManaged:
                break
                
            case .finishManaged:
                break
            }
            
        case .restartTimerExpired(let train):
            // Only restart the train if it is still automatically managed
            if train.scheduling == .managed && train == self.train {
                train.startRouteIndex = train.routeStepIndex
            }
            
        case .turnoutChanged:
            break
        case .directionChanged:
            break
        case .speedChanged:
            if train.speed.actualKph == 0 && train.state == .stopping {
                train.state = .stopped
                try handleTrainStopped()
                resultingEvents.append(.stateChanged)
            }
            break
        case .stateChanged:
            break
        case .movedInsideBlock:
            break
        case .movedToNextBlock:
            break
        case .reservedBlocksChanged:
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
            
            // Note: do not remove the leading blocks as this will be taken care below by the `reserveLeadingBlocks` method.
            // This is important because the reserveLeadingBlocks method needs to remember the previously reserved turnouts
            // in order to avoid re-activating them each time unnecessarily.
            try executor.setTrainPosition(train, position, removeLeadingBlocks: false)
            
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

        // Note: do not remove the leading blocks as this will be taken care below by the `reserveLeadingBlocks` method.
        // This is important because the reserveLeadingBlocks method needs to remember the previously reserved turnouts
        // in order to avoid re-activating them each time unnecessarily.
        try executor.setTrainToBlock(train, entryFeedback.block.id, position: .custom(value: position), direction: entryFeedback.direction, routeIndex: train.routeStepIndex + 1, removeLeadingBlocks: false)
        
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
        
        guard train.scheduling == .managed else {
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
            executor.setTrainSpeed(train, LayoutFactory.DefaultMaximumSpeed, completion: nil)
            resultingEvents.append(.stateChanged)
        }
    }
    
    func handleTrainBrake() {
        guard train.state == .running && trainShouldStop && brakingFeedbackTriggered else {
            return
        }
        
        BTLogger.router.debug("\(self.train, privacy: .public): braking in \(self.currentBlock.name, privacy: .public) at position \(self.train.position), direction \(self.trainInstance.direction)")
        train.state = .braking
        executor.setTrainSpeed(train, currentBlock.brakingSpeed ?? LayoutFactory.DefaultBrakingSpeed, completion: nil)
        resultingEvents.append(.stateChanged)
    }
    
    func handleTrainStop() throws {
        guard train.state == .running || train.state == .braking else {
            return
        }
        
        guard trainShouldStop && stoppingFeedbackTriggered else {
            return
        }

        BTLogger.router.debug("\(self.train, privacy: .public): stopping in \(self.currentBlock.name, privacy: .public) at position \(self.train.position), direction \(self.trainInstance.direction)")
        
        train.state = .stopping
        
        executor.setTrainSpeed(train, 0, completion: nil)
                        
        resultingEvents.append(.stateChanged)
    }
    
    func handleTrainStopped() throws {
        try reservation.removeLeadingBlocks(train: train)

        let reachedStationOrDestination = layout.hasTrainReachedStationOrDestination(route, train, currentBlock)
        let stopCompletely = (reachedStationOrDestination && train.scheduling == .finishManaged) || train.scheduling == .stopManaged
        
        switch route.mode {
        case .fixed:
            if stopCompletely || trainAtEndOfRoute {
                train.scheduling = .unmanaged
            } else if reachedStationOrDestination {
                reschedule(train: train, delay: waitingTime)
            }

        case .automatic:
            if stopCompletely {
                train.scheduling = .unmanaged
            } else if reachedStationOrDestination {
                reschedule(train: train, delay: waitingTime)
            }

        case .automaticOnce(destination: _):
            break
        }
    }
    
    func reschedule(train: Train, delay: TimeInterval) {
        BTLogger.router.debug("\(train, privacy: .public): schedule timer to restart train in \(delay, format: .fixed(precision: 1)) seconds")
        
        train.timeUntilAutomaticRestart = delay
        executor.scheduleRestartTimer(train: train)
    }
        
    // TODO: unit test to test the resulting event with change and no change
    func reserveLeadingBlocks() throws {
        switch route.mode {
        case .fixed:
            if try reservation.updateReservedBlocks(train: train) == .success {
                resultingEvents.append(.reservedBlocksChanged)
            }

        case .automatic, .automaticOnce(destination: _):
            let result = try reservation.updateReservedBlocks(train: train)
            if result != .failure {
                if result == .success {
                    resultingEvents.append(.reservedBlocksChanged)
                }
                return
            }

            if layout.hasTrainReachedStationOrDestination(route, train, currentBlock) {
                return
            }
            
            BTLogger.router.debug("\(self.train, privacy: .public): generating a new route at \(self.currentBlock.name, privacy: .public) because the leading blocks could not be reserved for \(self.route.steps.debugDescription, privacy: .public)")
            
            // Update the automatic route
            if try updateAutomaticRoute(for: train, layout: layout) {
                // And try to reserve the lead blocks again
                if try reservation.updateReservedBlocks(train: train) == .success {
                    resultingEvents.append(.reservedBlocksChanged)
                }
            }
        }
    }
    
    /// Adjusts the speed of the train to the maximum allowed speed authorized.
    ///
    /// The maximum speed takes several factors into condition, including the blocks and turnouts
    /// speed restrictions that the train is located on, as well as the leading reserved blocks distance
    /// to make sure the train has enough distance to safely brake to a halt if necessary.
    ///
    /// This method only affects trains running in automatic scheduling. Manual scheduling is not monitored.
    /// - Parameter train: the train to adjust the speed
    private func adjustSpeedLimit(_ train: Train) {
        guard train.scheduling == .managed && train.state == .running else {
            return
        }

        executor.setTrainSpeed(train, LayoutFactory.DefaultMaximumSpeed, speedLimit: true, force: false, acceleration: nil, completion: nil)
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
