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
    let functionsController: TrainFunctionsController
    let reservation: LayoutReservation
    let layoutSpeed: LayoutSpeed

    /// The block at the front of the train in the direction of travel
    var frontBlock: Block? {
        assert(train.frontBlockId != nil)
        return layout.blocks[train.frontBlockId]
    }

    var description: String {
        "TrainController(layout=\(layout.name), train=\(train.description(layout)))"
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
        guard let frontBlock = frontBlock else {
            return false
        }

        guard let trainInstance = frontBlock.trainInstance else {
            return false
        }

        guard let brakeFeedback = frontBlock.brakeFeedback(for: trainInstance.direction) else {
            return false
        }

        return isFeedbackTriggered(layout: layout, block: frontBlock, feedbackId: brakeFeedback)
    }

    var stopFeedbackActivated: Bool {
        guard let frontBlock = frontBlock else {
            return false
        }

        guard let trainInstance = frontBlock.trainInstance else {
            return false
        }

        guard let stopFeedback = frontBlock.stopFeedback(for: trainInstance.direction) else {
            return false
        }

        return isFeedbackTriggered(layout: layout, block: frontBlock, feedbackId: stopFeedback)
    }

    func pastBrakeFeedback() throws -> Bool {
        try layout.isTrainLocatedAfterFeedback(train: train, type: .brake)
    }

    func pastStopFeedback() throws -> Bool {
        try layout.isTrainLocatedAfterFeedback(train: train, type: .stop)
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
        guard let frontBlock = frontBlock else {
            return false
        }

        return train.hasReachedStationOrDestination(route, frontBlock)
    }

    var shouldChangeDirection: Bool {
        guard let frontBlock = frontBlock else {
            return false
        }

        guard let directionInBlock = frontBlock.trainInstance?.direction else {
            return false
        }

        guard let routeItem = route.steps.element(at: train.routeStepIndex) else {
            return false
        }

        switch routeItem {
        case let .block(routeItemBlock):
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

    init(train: Train, route: Route, layout: Layout, layoutController: LayoutController, functionsController: TrainFunctionsController, reservation: LayoutReservation) {
        self.train = train
        self.route = route
        self.layout = layout
        self.layoutController = layoutController
        self.functionsController = functionsController
        self.reservation = reservation
        layoutSpeed = LayoutSpeed(layout: layout)
    }

    func reservedBlocksLengthEnough(forSpeed speed: SpeedKph) throws -> Bool {
        guard let frontBlock = frontBlock else {
            return false
        }
        // Even if there is enough space in the front block, we need to stop
        // the train if there are no leading distance available. Otherwise
        // the train might never stop because it might pass over the brake
        // feedback and then realize there is not enough distance. This is a limitation
        // of the current algorithm that does not take into consideration
        // the real location of the train (which has to be computed!).
        if train.leading.settledDistance == 0 {
            return false
        }

        return try layoutSpeed.isBrakingDistanceRespected(train: train, block: frontBlock, speed: speed)
    }

    func updatePosition(with _: Feedback) throws -> Bool {
        try moveTrain()
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
            reservation.removeOccupation(train: train)
            try layout.occupyBlocksWith(train: train)
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

            guard let frontBlock = frontBlock else {
                return
            }

            if train.hasReachedStationOrDestination(route, frontBlock) {
                return
            }

            BTLogger.router.debug("\(self.train.description(self.layout), privacy: .public): generating a new route at \(frontBlock.name, privacy: .public) because the leading blocks could not be reserved for route steps \(self.route.steps.description(self.layout), privacy: .public), occupied blocks \(self.train.occupied.blocks.toStrings(), privacy: .public)")

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
            BTLogger.router.debug("\(train.description(layout), privacy: .public): generated route is \(route.steps.description(layout), privacy: .public)")
            return true

        case let .failure(error):
            BTLogger.router.warning("\(train.description(layout), privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func removeReservedBlocks() -> Bool {
        reservation.removeLeadingReservation(train: train)
    }

    func adjustSpeed() throws {
        guard let frontBlock = frontBlock else {
            BTLogger.router.warning("\(self.train.description(self.layout), privacy: .public): cannot adjust speed because the front block is not defined")
            return
        }

        let desiredKph: SpeedKph?
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

        guard let desiredKph = desiredKph else {
            return
        }

        // Ensure the desired speed respects any limitation due to any block or turnouts
        let requestedKph = min(desiredKph, try layoutSpeed.maximumSpeedAllowed(train: train, frontBlock: frontBlock))

        // Change the requested speed only if it is different from the current requested speed
        let loc = try train.locomotiveOrThrow()
        if requestedKph != loc.speed.requestedKph {
            BTLogger.speed.debug("\(self.train.description(self.layout), privacy: .public): controller adjusts speed to \(requestedKph)")
            try layoutController.setTrainSpeed(train, requestedKph)
        }
    }

    func stopImmediately() throws {
        BTLogger.speed.debug("\(self.train.description(self.layout), privacy: .public): stop immediately")
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

    /// Use any activated feedback to update the position(s) of the train.
    ///
    /// Note:
    /// - The updated positions of the train can span 1 or more blocks.
    /// - Returns: true if the positions have been updated, false otherwise
    func moveTrain() throws -> Bool {
        let currentPositions = train.positions

        var allFeedbacks = try layout.allOccupiedBlocksActiveFeedbackPositions(train: train)
        if let nextBlockFeedback = try layout.entryFeedback(for: train), nextBlockFeedback.feedback.detected {
            allFeedbacks.append(nextBlockFeedback)
        }

        for feedback in allFeedbacks {
            let detectedPosition = feedback.trainPosition
            train.positions = try train.positions.newPositionsWith(trainMovesForward: train.directionForward,
                                                                   detectedPosition: detectedPosition,
                                                                   reservation: train.reservation,
                                                                   tailDetected: train.isTailDetected)
            BTLogger.router.debug("\(self.train.description(self.layout), privacy: .public): updated location \(self.train.positions.description(self.layout)) by feedback \(feedback.description, privacy: .public)")
        }

        // Remember the previous occupied blocks to detect all the new blocks
        // that the train is now occupying.
        let previousOccupiedBlocks = train.occupied.blocks

        // Update the reserved block
        _ = try reservation.updateReservedBlocks(train: train)

        // Determine any new block(s) that the train is now occpuying
        var newBlocks = [Block]()
        for occupiedBlock in train.occupied.blocks {
            if !previousOccupiedBlocks.contains(where: { $0.id == occupiedBlock.id }) {
                newBlocks.append(occupiedBlock)
            }
        }

        BTLogger.router.debug("\(self.train.description(self.layout), privacy: .public): occupying new blocks \(newBlocks.description)")

        if !newBlocks.isEmpty {
            // For each new block that the train occupies, ensure the route index is updated
            // and execute any actions related to entering a new block
            for newBlock in newBlocks {
                BTLogger.router.debug("\(self.train.description(self.layout), privacy: .public): update route index and execute functions for new block \(newBlock.description(self.layout))")

                // Update the current route step index
                train.routeStepIndex += 1

                // Execute the functions of the new block
                executeFunctions()
            }
        }

        return train.positions != currentPositions
    }

    func reschedule() {
        reschedule(train: train, delay: waitingTime)
    }

    func reschedule(train: Train, delay: TimeInterval) {
        BTLogger.router.debug("\(train.description(self.layout), privacy: .public): schedule timer to restart train in \(delay, format: .fixed(precision: 1)) seconds")

        train.timeUntilAutomaticRestart = delay
        layoutController.scheduleRestartTimer(train: train)
    }

    func routeWillStart() {
        if let functions = route.startFunctions {
            functionsController.execute(functions: functions, train: train)
        }
    }

    func routeDidStop() {
        if let functions = route.stopFunctions {
            functionsController.execute(functions: functions, train: train)
        }
    }

    func executeFunctions() {
        guard let routeItem = route.steps.element(at: train.routeStepIndex) else {
            return
        }

        switch routeItem {
        case let .block(block):
            if let functions = block.functions {
                functionsController.execute(functions: functions, train: train)
            }

        case .turnout:
            break

        case let .station(station):
            if let functions = station.functions {
                functionsController.execute(functions: functions, train: train)
            }
        }
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
            return frontBlock?.waitingTime ?? 0
        }
    }

    func logDebug(_ message: String) {
        BTLogger.router.debug("\(self.train.description(self.layout), privacy: .public): \(message, privacy: .public)")
    }
}
