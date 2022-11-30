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

import Combine
import Foundation
import OrderedCollections

/// Abstraction of the LayoutController
protocol LayoutControlling: AnyObject {
    func start(routeID: Identifier<Route>, trainID: Identifier<Train>) throws
    func stop(train: Train)
}

/**
 Manages the operation of all the trains in the layout.

 When BTrain manages a train, it must ensure the train starts, stops
 and brakes appropriately to avoid collision with other trains and respect
 the constraints of the layout while following the indication of the route
 assigned to the train. BTrain does this by responding to events from the layout,
 such as ``LayoutControllerEvent/feedbackTriggered`` when a feedback is triggered
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
final class LayoutController: ObservableObject, LayoutControlling {
    /// True to enable the control of the layout, false otherwise. For example, the locomotive speed measurement
    /// is turning the layout controller off in order to freely move a locomotive between feedbacks without having
    /// to take into account any unexpected feedback being triggered.
    var enabled = true

    // The layout being managed
    let layout: Layout

    /// The observer that keeps us informed of any change in the layout
    let layoutObserver: LayoutObserver

    /// A helper class that monitors feedbacks
    let feedbackMonitor: LayoutFeedbackMonitor

    /// The interface to the Digital Controller
    var interface: CommandInterface

    /// The switchboard state, used to refresh the switchboard
    /// when certain events happen in the layout controller
    let switchboard: SwitchBoard?

    /// The layout script conductor
    let conductor: LayoutScriptConductor

    lazy var reservation: LayoutReservation = .init(layout: layout, executor: self, verbose: SettingsKeys.bool(forKey: SettingsKeys.logReservation))

    /// Describes a feedback in the layout
    struct FeedbackAttributes {
        let deviceID: UInt16
        let contactID: UInt16
    }

    /// Contains the last detected feedback in the layout. This feedback does not necessarily belongs
    /// to the list of feedbacks declared in the layout. For example, a new feedback added to the physical
    /// layout will be detected but might not have been added, yet, to the list of feedbacks by the user.
    @Published var lastDetectedFeedback: FeedbackAttributes?

    /// A map of locomotive to an instance of the speed manager for that locomotive
    private var speedManagers = [Identifier<Locomotive>: LocomotiveSpeedManager]()

    /// The turnout manager class that handles the turnout change towards the Digital Controller
    private var turnoutManager: LayoutTurnoutManager

    let debugger: LayoutControllerDebugger

    #if DEBUG
        static var memoryLeakCounter = 0
    #endif

    init(layout: Layout, switchboard: SwitchBoard?, interface: CommandInterface) {
        self.layout = layout
        layoutObserver = LayoutObserver(layout: layout)
        feedbackMonitor = LayoutFeedbackMonitor(layout: layout)
        self.switchboard = switchboard
        self.interface = interface
        conductor = LayoutScriptConductor(layout: layout)
        turnoutManager = LayoutTurnoutManager(interface: interface)
        debugger = LayoutControllerDebugger(layout: layout)

        registerForFeedbackChange()
        registerForDirectionChange()
        registerForTurnoutChange()
        registerForTrainChange()

        conductor.layoutControlling = self

        #if DEBUG
            LayoutController.memoryLeakCounter += 1
        #endif
    }

    #if DEBUG
        deinit {
            LayoutController.memoryLeakCounter -= 1
        }
    #endif

    /// Run each train controller on the specified train event
    /// - Parameter event: the train event
    func runControllers(_ event: LayoutControllerEvent) {
        run(event)
        redrawSwitchboard()
    }

    private func run(_ event: LayoutControllerEvent) {
        guard enabled else {
            return
        }

        if let runtimeError = layout.runtimeError {
            BTLogger.router.error("⚙ Cannot evaluate the layout because there is a runtime error: \(runtimeError, privacy: .public)")
            return
        }
        BTLogger.router.debug("⚙ Evaluating the layout for '\(event, privacy: .public)'")

        // Run each controller one by one, using
        // the sorted keys to ensure they always
        // run in the same order.
        do {
            // Update and detect any unexpected feedbacks
            try updateExpectedFeedbacks()

            // Purge any invalid restart timers
            purgeRestartTimers()

            // Invoke the layout state machine which will process the train event
            let lsm = LayoutStateMachine()
            var events: [StateMachine.TrainEvent]? = []
            try lsm.handle(layoutEvent: event.layoutEvent(layoutController: self),
                           trainEvent: event.trainEvent(layoutController: self),
                           trains: layout.trains.elements.compactMap { train in trainController(forTrain: train) },
                           handledTrainEvents: &events)
            #if DEBUG
                if let events = events {
                    BTLogger.debug("Handled events: \(events)")
                }
            #endif

            // Update and detect any unexpected feedbacks
            // Note: it is necessary to repeat this step after
            // running all the train controllers because a train
            // might have moved and hence the expected feedbacks
            // should be updated promptly to reflect the new state.
            try updateExpectedFeedbacks()

            // Update and run any layout scripts
            try conductor.tick()
        } catch {
            // Stop everything in case there is a problem processing the layout
            BTLogger.router.error("Stopping all trains because there is an error processing the layout: \(error.localizedDescription, privacy: .public)")
            layout.runtimeError = error.localizedDescription
            dumpAll()
            haltAll()
        }

        debugger.record(layoutController: self)
    }

    func trainController(forTrain train: Train) -> TrainController? {
        guard let frontBlock = train.block else {
            return nil
        }
        
        guard let trainInstance = frontBlock.trainInstance else {
            return nil
        }

        guard let route = layout.route(for: train.routeId, trainId: train.id) else {
            return nil
        }

        return TrainController(train: train, route: route, layout: layout, frontBlock: frontBlock, frontBlockTrainInstance: trainInstance, layoutController: self, reservation: reservation)
    }

    private func updateExpectedFeedbacks() throws {
        switchboard?.context.expectedFeedbackIds = nil
        switchboard?.context.unexpectedFeedbackIds = nil

        if layout.detectUnexpectedFeedback {
            try feedbackMonitor.update(with: layout.trains.elements)
            switchboard?.context.expectedFeedbackIds = feedbackMonitor.expectedFeedbacks
            do {
                try feedbackMonitor.handleUnexpectedFeedbacks()
            } catch let LayoutError.unexpectedFeedback(feedback) {
                switchboard?.context.unexpectedFeedbackIds = [feedback.id]
                throw LayoutError.unexpectedFeedback(feedback: feedback)
            }
        }
    }

    private func haltAll() {
        stopAll(includingManualTrains: true)

        // Send the command to zero the speed of each train
        // because the run() method won't run until the runtimeError
        // is cleared by the user. We want to make sure the train don't
        // start again if the user re-enable the layout manually.
        for train in layout.trains.elements {
            try? setTrainSpeed(train, 0)
            train.scheduling = .unmanaged
        }

        // Stop the Digital Controller to ensure nothing moves further
        stop {}

        // Invalidate every restart timer
        pausedTrainTimers.forEach { $0.value.invalidate() }
        pausedTrainTimers.removeAll()
    }

    // MARK: Commands

    func go(onCompletion: @escaping CompletionBlock) {
        interface.execute(command: .go(), completion: onCompletion)
    }

    func stop(onCompletion: @escaping CompletionBlock) {
        interface.execute(command: .stop(), completion: onCompletion)
    }

    func startAll() {
        for train in layout.trainsThatCanBeStarted() {
            do {
                try start(routeID: train.routeId, trainID: train.id, destination: nil)
            } catch {
                BTLogger.router.error("Unable to start \(train.name): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Stops the specified train as soon as possible.
    ///
    /// The first call to this method stops the train as soon as possible, when
    /// the train as entered a block and triggered the stop feedback.
    ///
    /// Calling this method again while the train is stopping is going to stop it immediately.
    ///
    /// - Parameter train: the train to stop
    func stop(train: Train) {
        if train.scheduling == .stopManaged {
            train.scheduling = .stopImmediatelyManaged
        } else {
            train.scheduling = .stopManaged
        }
        runControllers(.schedulingChanged(train))
    }

    func stopAll(includingManualTrains: Bool) {
        let trains: [Train]
        if includingManualTrains {
            trains = layout.trains.elements
        } else {
            trains = layout.trainsThatCanBeStopped()
        }
        for train in trains {
            stop(train: train)
        }
    }

    func finish(train: Train) {
        train.scheduling = .finishManaged
        runControllers(.schedulingChanged(train))
    }

    func finishAll() {
        for train in layout.trainsThatCanBeFinished() {
            finish(train: train)
        }
    }

    func remove(train: Train) throws {
        try layout.remove(trainId: train.id)
        runControllers(.trainPositionChanged(train))
    }

    // MARK: Layout Scripts

    func schedule(scriptId: Identifier<LayoutScript>) {
        conductor.schedule(scriptId)
        runControllers(.scriptScheduled)
    }

    func stop(scriptId: Identifier<LayoutScript>) throws {
        try conductor.stop(scriptId)
    }

    func isRunning(scriptId: Identifier<LayoutScript>?) -> Bool {
        conductor.currentScript?.id == scriptId && scriptId != nil
    }

    // MARK: Paused Train Management

    // A map that contains all trains that are currently paused
    // and need to be restarted at a later time. Each train
    // has an associated timer that fires when it is time to
    // restart the train
    var pausedTrainTimers = [Identifier<Train>: Timer]()

    /// Request to restart the train after a specific amount of time specified by the route and block.
    /// - Parameter train: the train to restart after some amount of time
    func scheduleRestartTimer(train: Train) {
        guard train.timeUntilAutomaticRestart > 0 else {
            return
        }

        // Start a timer that will restart the train with a new automatic route
        // Note: the timer fires every second to update the remaining time until it reaches 0.
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] timer in
            train.timeUntilAutomaticRestart -= 1
            if train.timeUntilAutomaticRestart <= 0 {
                BTLogger.router.debug("It is now time to restart train \(train, privacy: .public)")
                // The TrainController is the class that actually restarts the train
                // when it sees that this timer has reached 0 and all other parameters are valid.
                self?.restartTimerFired(train)
                timer.invalidate()
            }
            // Redraw the switchboard so the time interval is refreshed
            self?.redrawSwitchboard()
        })
        pausedTrainTimers[train.id] = timer
    }

    func purgeRestartTimers() {
        // Remove any expired timer
        pausedTrainTimers = pausedTrainTimers.filter { $0.value.isValid }
    }

    func restartTimerFired(_ train: Train) {
        train.timeUntilAutomaticRestart = 0
        runControllers(.restartTimerExpired(train))
    }

    func redrawSwitchboard() {
        switchboard?.state.triggerRedraw.toggle()
    }
}

extension LayoutController {
    func registerForTrainChange() {
        layoutObserver.registerForTrainChange { [weak self] trains in
            self?.updateSpeedManagers(with: trains)
        }

        updateSpeedManagers(with: layout.trains.elements)
    }

    func speedManager(for loc: Locomotive, train: Train) -> LocomotiveSpeedManager {
        if let speedManager = speedManagers[loc.id] {
            return speedManager
        } else {
            let speedManager = LocomotiveSpeedManager(loc: loc, interface: interface, speedChanged: { [weak self] in
                self?.runControllers(.speedChanged(train, loc.speed.actualKph))
            })
            speedManagers[loc.id] = speedManager
            return speedManager
        }
    }

    func updateSpeedManagers(with trains: [Train]) {
        var existingSpeedManagers = [Identifier<Locomotive>: LocomotiveSpeedManager]()
        for train in trains {
            if let loc = train.locomotive {
                existingSpeedManagers[loc.id] = speedManager(for: loc, train: train)
            }
        }

        // Remove controllers that don't belong to an existing train
        speedManagers = existingSpeedManagers
    }
}

extension LayoutController {
    func prepare(routeID: Identifier<Route>, trainID: Identifier<Train>, destination: Destination? = nil) throws {
        guard let route = layout.route(for: routeID, trainId: trainID) else {
            throw LayoutError.routeNotFound(routeId: routeID)
        }

        guard let train = layout.trains[trainID] else {
            throw LayoutError.trainNotFound(trainId: trainID)
        }

        // Note: do not prepare the route if the train is already running under
        // management control because it might change the route type (from automaticOnce
        // to automatic) when this view appears (due to filtering for example).
        guard train.scheduling == .unmanaged else {
            throw LayoutError.cannotChangeRouteWhileTrainIsRunning(train: train, route: route)
        }

        // Set the route to the train
        train.routeId = routeID

        if route.automatic {
            // Ensure the automatic route associated with the train is updated
            // Note: remember the destination block
            if let destination = destination {
                route.mode = .automaticOnce(destination: destination)
            } else {
                route.mode = .automatic
            }

            // Reset the route - the route will be automatically updated by
            // the TrainController when the train is started.
            train.routeStepIndex = 0
            train.startRouteIndex = 0
            route.steps.removeAll()
        } else {
            // Check to make sure the train is somewhere along the route
            train.routeStepIndex = -1
            try route.completePartialSteps(layout: layout, train: train)
            for (index, step) in route.steps.enumerated() {
                guard let (blockId, direction) = layout.block(for: train, step: step) else {
                    continue
                }

                guard train.block?.id == blockId else {
                    continue
                }

                guard let block = train.block else {
                    continue
                }

                guard let trainInstance = block.trainInstance else {
                    continue
                }

                // Check that the train direction matches as well.
                if trainInstance.direction == direction {
                    train.routeStepIndex = index
                    train.startRouteIndex = index
                    break
                }
            }

            guard train.routeStepIndex >= 0 else {
                throw LayoutError.trainNotFoundInRoute(train: train, route: route)
            }
        }
    }

    func start(routeID: Identifier<Route>, trainID: Identifier<Train>) throws {
        try start(routeID: routeID, trainID: trainID, destination: nil)
    }

    func start(routeID: Identifier<Route>, trainID: Identifier<Train>, destination: Destination? = nil) throws {
        guard let train = layout.trains[trainID] else {
            throw LayoutError.trainNotFound(trainId: trainID)
        }

        try prepare(routeID: routeID, trainID: trainID, destination: destination)

        train.scheduling = .managed
        runControllers(.schedulingChanged(train))
    }

    /// Send a turnout state command
    ///
    /// - Parameters:
    ///   - turnout: the turnout whose state need to be sent to the Digital Controller
    ///   - completion: completion block called when the command has been sent
    func sendTurnoutState(turnout: Turnout, completion: @escaping CompletionCancelBlock) {
        guard turnout.enabled else {
            completion(false)
            return
        }
        turnout.actualStateReceived = false
        turnoutManager.sendTurnoutState(turnout: turnout, completion: completion)
    }

    func setTrainSpeed(_ train: Train, _ speed: SpeedKph, acceleration: LocomotiveSpeedAcceleration.Acceleration? = nil, completion: CompletionCancelBlock? = nil) throws {
        guard let loc = train.locomotive else {
            throw LayoutError.locomotiveNotAssignedToTrain(train: train)
        }
        loc.speed.requestedKph = speed
        try setTrainSpeed(train, loc.speed.requestedSteps, acceleration: acceleration, completion: completion)
    }

    func setTrainSpeed(_ train: Train, _ speed: SpeedStep, acceleration: LocomotiveSpeedAcceleration.Acceleration? = nil, completion: CompletionCancelBlock? = nil) throws {
        guard let loc = train.locomotive else {
            throw LayoutError.locomotiveNotAssignedToTrain(train: train)
        }
        loc.speed.requestedSteps = speed
        let speedManager = speedManager(for: loc, train: train)
        if let acceleration = acceleration {
            speedManager.changeSpeed(acceleration: acceleration, completion: completion)
        } else {
            speedManager.changeSpeed(completion: completion)
        }
    }

    // Set the direction of travel of the locomotive
    func setLocomotiveDirection(_ loc: Locomotive, forward: Bool, completion: CompletionBlock? = nil) {
        guard loc.directionForward != forward else {
            completion?()
            return
        }

        BTLogger.router.debug("\(loc, privacy: .public): change train direction to \(forward ? "forward" : "backward")")
        let command: Command
        if forward {
            command = .direction(address: loc.address, decoderType: loc.decoder, direction: .forward)
        } else {
            command = .direction(address: loc.address, decoderType: loc.decoder, direction: .backward)
        }
        interface.execute(command: command, completion: completion)
    }
    
    /// Toggles the direction of the train.
    ///
    /// An exception is thrown if the train does not allow for its direction to be changed.
    /// - Parameter train: the train
    func toggleTrainDirection(_ train: Train) throws {
        guard let blockId = train.block?.id else {
            throw LayoutError.trainNotAssignedToABlock(train: train)
        }

        guard let block = train.block else {
            throw LayoutError.blockNotFound(blockId: blockId)
        }

        guard let ti = block.trainInstance else {
            throw LayoutError.trainNotFoundInBlock(blockId: blockId)
        }

        guard ti.trainId == train.id else {
            throw LayoutError.trainInBlockDoesNotMatch(trainId: train.id, blockId: blockId, blockTrainId: ti.trainId)
        }

        if train.allowedDirections == .forward && !train.directionForward {
            // TODO: throw
            fatalError()
        }
                
        // Assign the new position of the train which is the same as the previous
        // position of the tail of the train.
        let newPosition = layout.trainPosition(train: train)
        
        // TODO: unit test this by having a separate method
        if let newPosition = newPosition,
           let tailBlockId = newPosition.back?.blockId ?? newPosition.front?.blockId,
            let tailBlock = layout.blocks[tailBlockId] {
            block.trainInstance = nil
            tailBlock.trainInstance = TrainInstance(train.id, ti.direction.opposite)
            train.position = newPosition
            train.block = tailBlock
        } else {
            block.trainInstance = TrainInstance(train.id, ti.direction.opposite)
            BTLogger.warning("Unable to properly set the train position after toggling locomotive direction: \(train)")
        }

        try reservation.removeLeadingBlocks(train: train)
    }
    
    /// Setup the train in a block. This method places the train for the first time in the specified block, filling the block with the train
    /// by respecting the specified natural direction of the train in the block.
    ///
    /// - Parameters:
    ///   - train: the train
    ///   - toBlockId: the block
    ///   - naturalDirectionInBlock: the natural direction of the train
    func setupTrainToBlock(_ train: Train, _ toBlockId: Identifier<Block>, naturalDirectionInBlock: Direction) throws {
        guard let toBlock = layout.blocks[toBlockId] else {
            throw LayoutError.blockNotFound(blockId: toBlockId)
        }
        
        guard toBlock.trainInstance == nil || toBlock.trainInstance?.trainId == train.id else {
            throw LayoutError.blockNotEmpty(blockId: toBlockId)
        }
        
        guard toBlock.reservation == nil || toBlock.reservation?.trainId == train.id else {
            throw LayoutError.cannotReserveBlock(block: toBlock, train: train, reserved: toBlock.reservation!)
        }
        
        if naturalDirectionInBlock == .next {
            if train.allowedDirections == .forward {
                train.position = .both(blockId: toBlockId, index: toBlock.feedbacks.count)
            } else {
                train.position = .block(blockId: toBlockId, front: toBlock.feedbacks.count, back: 0)
            }
        } else {
            if train.allowedDirections == .forward {
                train.position = .both(blockId: toBlockId, index: 0)
            } else {
                train.position = .block(blockId: toBlockId, front: 0, back: toBlock.feedbacks.count)
            }
        }
        
        let directionInBlock: Direction
        if train.directionForward {
            directionInBlock = naturalDirectionInBlock
        } else {
            directionInBlock = naturalDirectionInBlock.opposite
        }

        try layout.setTrainToBlock(train, toBlockId, position: train.position, directionOfTravelInBlock: directionInBlock)
        
        try reservation.removeLeadingBlocks(train: train)
    }
    

}

extension LayoutController: MetricsProvider {
    var metrics: [Metric] {
        turnoutManager.metrics + interface.metrics + [.init(id: "Speed Changes", value: String(LocomotiveSpeedManager.globalRequestUUID))]
    }
}

extension LayoutTurnoutManager: MetricsProvider {
    var metrics: [Metric] {
        [.init(id: turnoutQueue.name, value: String(turnoutQueue.scheduledCount))]
    }
}
