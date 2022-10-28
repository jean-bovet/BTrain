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

final class TrainController: TrainControlling, CustomStringConvertible {
    let train: Train
    let route: Route
    let layout: Layout
    let layoutController: LayoutController
    let reservation: LayoutReservation
    let layoutSpeed: LayoutSpeed
    
    var currentBlock: Block
    var trainInstance: TrainInstance

    var description: String {
        "TrainController(layout=\(layout.name), train=\(train))"
    }
    
    var id: String {
        train.id.uuid
    }
    
    var mode: StateMachine.TrainMode {
        get {
            train.scheduling
        }
        set {
            train.scheduling = newValue
        }
    }
    
    var state: StateMachine.TrainState {
        get {
            train.state
        }
        set {
            train.state = newValue
        }
    }
    
    var speed: TrainSpeed.UnitKph {
        get {
            train.speed.actualKph
        }
        set {
            train.speed.actualKph = newValue
        }
    }
    
    var brakeFeedbackActivated: Bool {
        guard let brakeFeedback = currentBlock.brakeFeedback(for: trainInstance.direction) else {
            return false
        }
        
        return isFeedbackTriggered(layout: layout, train: train, feedbackId: brakeFeedback)
    }
    
    var stopFeedbackActivated: Bool {
        guard let stopFeedback = currentBlock.stopFeedback(for: trainInstance.direction) else {
            return false
        }
        
        return isFeedbackTriggered(layout: layout, train: train, feedbackId: stopFeedback)
    }
    
    var startedRouteIndex: Int {
        get {
            train.startRouteIndex ?? 0
        }
        set {
            train.startRouteIndex = newValue
        }
    }
    
    var currentRouteIndex: Int {
        train.routeStepIndex
    }
    
    var endRouteIndex: Int {
        return route.lastStepIndex
    }
    
    var atEndOfRoute: Bool {
        train.routeStepIndex == route.lastStepIndex
    }
    
    var atStationOrDestination: Bool {
        layout.hasTrainReachedStationOrDestination(route, train, currentBlock)
    }
    
    var reservedBlocksSettling: Bool {
        train.leading.settling
    }
    
    init(train: Train, route: Route, layout: Layout, currentBlock: Block, trainInstance: TrainInstance, layoutController: LayoutController, reservation: LayoutReservation) {
        self.train = train
        self.route = route
        self.layout = layout
        self.currentBlock = currentBlock
        self.trainInstance = trainInstance
        self.layoutController = layoutController
        self.reservation = reservation
        self.layoutSpeed = LayoutSpeed(layout: layout)
    }
    
    func reservedBlocksLengthEnough(forSpeed speed: TrainSpeed.UnitKph) -> Bool {
        return layoutSpeed.isBrakingDistanceRespected(train: train, speed: speed)
    }
    
    func updatePosition(with feedback: Feedback) throws -> Bool {
        if try moveInsideBlock() {
            return true
        } else if try moveToNextBlock() {
            return true
        }
        return false
    }
    
    func updateReservedBlocksSettledLength(with turnout: Turnout) -> Bool {
        train.leading.updateSettledDistance()
    }
    
    func updateOccupiedAndReservedBlocks() throws -> Bool {
        try updateReservedBlocks()
    }
    
    func updateReservedBlocks() throws -> Bool {
        let previousLeadingItems = train.leading.items
        let previousOccupiedItems = train.occupied.items

        if mode == .unmanaged {
            try reservation.freeElements(train: train)
            try reservation.occupyBlocksWith(train: train)
        } else {
            try reserveLeadingBlocks()
        }
        
        return previousLeadingItems != train.leading.items || previousOccupiedItems != train.occupied.items
    }
    
    func reserveLeadingBlocks() throws {
        switch route.mode {
        case .fixed:
            _ = try reservation.updateReservedBlocks(train: train)

        case .automatic, .automaticOnce(destination: _):
            let result = try reservation.updateReservedBlocks(train: train)
            if result != .failure {
                return
            }

            if layout.hasTrainReachedStationOrDestination(route, train, currentBlock) {
                return
            }
            
            BTLogger.router.debug("\(self.train, privacy: .public): generating a new route at \(self.currentBlock.name, privacy: .public) because the leading blocks could not be reserved for \(self.route.steps.debugDescription, privacy: .public)")
            
            // Update the automatic route
            if try updateAutomaticRoute(for: train, layout: layout) {
                // And try to reserve the lead blocks again
                _ = try reservation.updateReservedBlocks(train: train)
            }
        }
    }

    private func updateAutomaticRoute(for train: Train, layout: Layout) throws -> Bool {
        let result = try layout.automaticRouting.updateAutomaticRoute(for: train.id)
        switch result {
        case .success(let route):
            BTLogger.router.debug("\(train, privacy: .public): generated route is \(route.steps.debugDescription, privacy: .public)")
            return true

        case .failure(let error):
            BTLogger.router.warning("\(train, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false

        }
    }

    func removeReservedBlocks() throws -> Bool {
        try reservation.removeLeadingBlocks(train: train)
    }
    
    func adjustSpeed(stateChanged: Bool) {
        let desiredKph: TrainSpeed.UnitKph?
        if stateChanged {
            switch train.state {
            case .running:
                desiredKph = LayoutFactory.DefaultMaximumSpeed
            case .braking:
                desiredKph = currentBlock.brakingSpeed ?? LayoutFactory.DefaultBrakingSpeed
            case .stopping:
                desiredKph = 0
            case .stopped:
                desiredKph = nil
            }
        } else if train.state == .running {
            // When running, always try to use the maximum speed.
            // Note: it will be lowered if necessary below.
            desiredKph = LayoutFactory.DefaultMaximumSpeed
        } else {
            desiredKph = nil
        }
        
        if let desiredKph = desiredKph {
            let requestedKph = min(desiredKph, layoutSpeed.maximumSpeedAllowed(train: train))
            if requestedKph != train.speed.requestedKph {
                BTLogger.speed.debug("\(self.train, privacy: .public): controller adjusts speed to \(requestedKph)")
                layoutController.setTrainSpeed(train, requestedKph)
            }
        }
    }
 
    // MARK: --
    
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
            try layoutController.setTrainPosition(train, position, removeLeadingBlocks: false)
            
            BTLogger.router.debug("\(self.train, privacy: .public): moved to position \(self.train.position) in \(self.currentBlock.name, privacy: .public), direction \(self.trainInstance.direction)")
                        
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
        try layoutController.setTrainToBlock(train, entryFeedback.block.id, position: .custom(value: position), direction: entryFeedback.direction, routeIndex: train.routeStepIndex + 1, removeLeadingBlocks: false)
        
        guard let newBlock = layout.block(for: entryFeedback.block.id) else {
            throw LayoutError.blockNotFound(blockId: entryFeedback.block.id)
        }
        
        currentBlock = newBlock
        
        guard let newTrainInstance = newBlock.trainInstance else {
            throw LayoutError.trainNotFoundInBlock(blockId: newBlock.id)
        }
        
        trainInstance = newTrainInstance
                
        return true
    }
    
    func reschedule() {
        reschedule(train: train, delay: waitingTime)
    }
    
    func reschedule(train: Train, delay: TimeInterval) {
        BTLogger.router.debug("\(train, privacy: .public): schedule timer to restart train in \(delay, format: .fixed(precision: 1)) seconds")
        
        train.timeUntilAutomaticRestart = delay
        layoutController.scheduleRestartTimer(train: train)
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

}
