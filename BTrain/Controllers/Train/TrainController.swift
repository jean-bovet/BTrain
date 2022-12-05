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
    
    /// The block at the front of the train in the direction of travel
    var frontBlock: Block
    
    /// The train instance of the front block
    var frontBlockTrainInstance: TrainInstance

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

    var speed: SpeedKph {
        get {
            train.locomotive?.speed.actualKph ?? 0
        }
        set {
            train.locomotive?.speed.actualKph = newValue
        }
    }

    var brakeFeedbackActivated: Bool {
        guard let brakeFeedback = frontBlock.brakeFeedback(for: frontBlockTrainInstance.direction) else {
            return false
        }

        return isFeedbackTriggered(layout: layout, block: frontBlock, feedbackId: brakeFeedback)
    }

    var stopFeedbackActivated: Bool {
        guard let stopFeedback = frontBlock.stopFeedback(for: frontBlockTrainInstance.direction) else {
            return false
        }

        return isFeedbackTriggered(layout: layout, block: frontBlock, feedbackId: stopFeedback)
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
        route.lastStepIndex
    }

    var atEndOfRoute: Bool {
        train.routeStepIndex == route.lastStepIndex
    }

    var atStationOrDestination: Bool {
        train.hasReachedStationOrDestination(route, frontBlock)
    }

    var shouldChangeDirection: Bool {
        guard let directionInBlock = frontBlock.trainInstance?.direction else {
            return false
        }

        guard let routeItem = route.steps.element(at: train.routeStepIndex) else {
            return false
        }

        switch routeItem {
        case .block(let routeItemBlock):
            return routeItemBlock.direction != directionInBlock
            
        case .turnout:
            return false
            
        case .station:
            return false
        }
    }
    
    var reservedBlocksSettling: Bool {
        train.leading.settling
    }

    init(train: Train, route: Route, layout: Layout, frontBlock: Block, frontBlockTrainInstance: TrainInstance, layoutController: LayoutController, reservation: LayoutReservation) {
        self.train = train
        self.route = route
        self.layout = layout
        self.frontBlock = frontBlock
        self.frontBlockTrainInstance = frontBlockTrainInstance
        self.layoutController = layoutController
        self.reservation = reservation
        layoutSpeed = LayoutSpeed(layout: layout)
    }

    func reservedBlocksLengthEnough(forSpeed speed: SpeedKph) throws -> Bool {
        try layoutSpeed.isBrakingDistanceRespected(train: train, speed: speed)
    }

    func updatePosition(with _: Feedback) throws -> Bool {
        if try moveInsideBlocks() {
            return true
        } else if try moveToNextBlock() {
            return true
        }
        return false
    }

    func updateReservedBlocksSettledLength(with _: Turnout) -> Bool {
        train.leading.updateSettledDistance()
    }

    func updateOccupiedAndReservedBlocks() throws -> Bool {
        try updateReservedBlocks()
    }

    func updateReservedBlocks() throws -> Bool {
        let previousLeadingItems = train.leading.items
        let previousOccupiedItems = train.occupied.items

        if mode == .unmanaged {
            reservation.removeOccupation(train: train) // TODO: unit test this behavior
            try reservation.occupyBlocksWith(train: train)
        } else {
            try reserveLeadingBlocks()
        }

        return previousLeadingItems != train.leading.items || previousOccupiedItems != train.occupied.items
    }

    private func reserveLeadingBlocks() throws {
        switch route.mode {
        case .fixed:
            _ = try reservation.updateReservedBlocks(train: train)

        case .automatic, .automaticOnce(destination: _):
            let result = try reservation.updateReservedBlocks(train: train)
            if result != .failure {
                return
            }

            if train.hasReachedStationOrDestination(route, frontBlock) {
                return
            }

            BTLogger.router.debug("\(self.train, privacy: .public): generating a new route at \(self.frontBlock.name, privacy: .public) because the leading blocks could not be reserved for route steps \(self.route.steps.debugDescription, privacy: .public), occupied blocks \(self.train.occupied.blocks, privacy: .public)")

            // Update the automatic route
            if try updateAutomaticRoute(for: train, layout: layout) {
                // And try to reserve the lead blocks again
                _ = try reservation.updateReservedBlocks(train: train)
            }
        }
    }

    private func updateAutomaticRoute(for train: Train, layout: Layout) throws -> Bool {
        let result = try layout.updateAutomaticRoute(for: train.id)
        switch result {
        case let .success(route):
            BTLogger.router.debug("\(train, privacy: .public): generated route is \(route.steps.debugDescription, privacy: .public)")
            return true

        case let .failure(error):
            BTLogger.router.warning("\(train, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func removeReservedBlocks() -> Bool {
        reservation.removeLeadingReservation(train: train)
    }

    func adjustSpeed(stateChanged: Bool) throws {
        let desiredKph: SpeedKph?
        if stateChanged {
            switch train.state {
            case .running:
                desiredKph = LayoutFactory.DefaultMaximumSpeed
            case .braking:
                desiredKph = frontBlock.brakingSpeed ?? LayoutFactory.DefaultBrakingSpeed
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
            let requestedKph = min(desiredKph, try layoutSpeed.maximumSpeedAllowed(train: train))
            let loc = try train.locomotiveOrThrow()
            if requestedKph != loc.speed.requestedKph {
                BTLogger.speed.debug("\(self.train, privacy: .public): controller adjusts speed to \(requestedKph)")
                try layoutController.setTrainSpeed(train, requestedKph)
            }
        }
    }

    func stopImmediately() throws {
        BTLogger.speed.debug("\(self.train, privacy: .public): stop immediately")
        try layoutController.setTrainSpeed(train, 0)
    }

    func changeDirection() throws {
        guard let loc = train.locomotive else {
            throw LayoutError.locomotiveNotAssignedToTrain(train: train)
        }
        layoutController.setLocomotiveDirection(loc, forward: !loc.directionForward)
    }
    
    // MARK: - -

    private func isFeedbackTriggered(layout: Layout, block: Block, feedbackId: Identifier<Feedback>) -> Bool {
        for bf in block.feedbacks {
            guard let f = layout.feedbacks[bf.feedbackId] else {
                continue
            }

            if feedbackId == f.id, f.detected {
                return true
            }
        }
        return false
    }

    func moveInsideBlocks() throws -> Bool {
        let currentPositions = train.positions
                
        // Note: do not remove the leading blocks as this will be taken care below by the `reserveLeadingBlocks` method.
        // This is important because the reserveLeadingBlocks method needs to remember the previously reserved turnouts
        // in order to avoid re-activating them each time unnecessarily.
        for feedback in try layout.allActiveFeedbackPositions(train: train) {
            guard let direction = try train.reservation.directionInBlock(for: feedback.blockId) else {
                // Note: this should not happen because all the feedback are in occupied block
                // which, by definition, have a train (and a direction) in them.
                throw LayoutError.directionNotFound(blockId: feedback.blockId)
            }
            let detectedPosition = feedback.trainPosition(direction: direction)
            train.positions = try train.positions.newPositionsWith(trainMovesForward: train.directionForward,
                                                                   detectedPosition: detectedPosition,
                                                                   reservation: train.reservation)
            BTLogger.router.debug("\(self.train, privacy: .public): updated location \(self.train.positions) in \(self.frontBlock.name, privacy: .public), direction \(self.frontBlockTrainInstance.direction)")
        }
        
        return train.positions != currentPositions
    }
        
    func moveToNextBlock() throws -> Bool {
        // Find out what is the entry feedback for the next block
        let entryFeedback = try layout.entryFeedback(for: train)
        guard let entryFeedback = entryFeedback, entryFeedback.feedback.detected else {
            return false
        }
        
        guard let blockFeedback = entryFeedback.block.feedbacks.first(where: { $0.feedbackId == entryFeedback.feedback.id }) else {
            throw LayoutError.feedbackNotFoundInBlock(feedbackId: entryFeedback.feedback.id, block: entryFeedback.block)
        }
        
        guard let fdistance = blockFeedback.distance else {
            throw LayoutError.feedbackDistanceNotSet(feedback: blockFeedback)
        }
        
        let feedbackPosition = FeedbackPosition(blockId: entryFeedback.block.id, index: entryFeedback.index, distance: fdistance)
        let detectedPosition = feedbackPosition.trainPosition(direction: entryFeedback.direction)

        let newPositions = try train.positions.newPositionsWith(trainMovesForward: train.directionForward,
                                                                detectedPosition: detectedPosition,
                                                                reservation: train.reservation)
        
        BTLogger.router.debug("\(self.train, privacy: .public): enters block \(entryFeedback.block, privacy: .public) at position \(feedbackPosition.index), direction \(entryFeedback.direction)")

        // Set the train position. Note that the occupied and leading blocks will be updated
        // later on by the state machine in response to the change in position of the train.
        try layout.setTrainToBlock(train, entryFeedback.block.id, positions: newPositions, directionOfTravelInBlock: entryFeedback.direction)

        // Update the current route step index
        train.routeStepIndex = train.routeStepIndex + 1

        guard let newBlock = layout.blocks[entryFeedback.block.id] else {
            throw LayoutError.blockNotFound(blockId: entryFeedback.block.id)
        }

        frontBlock = newBlock

        guard let newTrainInstance = frontBlock.trainInstance else {
            throw LayoutError.trainNotFoundInBlock(blockId: newBlock.id)
        }

        frontBlockTrainInstance = newTrainInstance

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
           case let .block(stepBlock) = step,
           let time = stepBlock.waitingTime
        {
            return time
        } else {
            // Use the block waiting time if the route itself has nothing specified
            return frontBlock.waitingTime
        }
    }
    
    func logDebug(_ message: String) {
        BTLogger.router.debug("\(self.train, privacy: .public): \(message, privacy: .public)")
    }
}
