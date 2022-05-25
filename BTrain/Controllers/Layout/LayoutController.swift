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
import Combine
import OrderedCollections

// This class is responsible for managing all the trains in the layout,
// including responding to feedback changes and ensuring the trains
// are properly following their route.
final class LayoutController {
    
    // The layout being managed
    let layout: Layout
    
    // A helper class that monitors feedbacks
    let feedbackMonitor: LayoutFeedbackMonitor
    
    // The interface to the Digital Controller
    var interface: CommandInterface
        
    // The switchboard state, used to refresh the switchboard
    // when certain events happen in the layout controller
    let switchboard: SwitchBoard?
    
    lazy var reservation: LayoutReservation = {
        LayoutReservation(layout: layout, executor: self, verbose: SettingsKeys.bool(forKey: SettingsKeys.logReservation))
    }()

    // Speed manager for each train.
    private var speedManagers = [Identifier<Train>:TrainSpeedManager]()

    // The executor that will send commands to the Digital Controller
    private var executor: LayoutCommandExecutor
    
    let debugger: LayoutControllerDebugger
    
    init(layout: Layout, switchboard: SwitchBoard?, interface: CommandInterface) {
        self.layout = layout
        self.switchboard = switchboard
        self.feedbackMonitor = LayoutFeedbackMonitor(layout: layout)
        self.interface = interface
        self.executor = LayoutCommandExecutor(layout: layout, interface: interface)
        self.debugger = LayoutControllerDebugger(layout: layout)
        
        registerForChange()
        
        updateControllers()
    }
        
    func registerForChange() {
        registerForFeedbackChange()
        registerForDirectionChange()
        registerForTurnoutChange()
    }
    
    func updateControllers() {
        for train in layout.trains {
            if speedManagers[train.id] == nil {
                let acceleration = TrainSpeedManager(train: train, interface: interface, speedChanged: { [weak self] in
                    self?.runControllers(.speedChanged)
                })
                speedManagers[train.id] = acceleration
            }
        }

        // Remove controllers that don't belong to an existing train
        speedManagers = speedManagers.filter({ element in
            layout.train(for: element.key) != nil
        })
    }
    
    /// Array of pending events that need to be processed by each train controller
    private var pendingEvents = [TrainEvent]()
    
    /// Run each train controller on the next train event
    /// - Parameter drain: true if all the pending train events should be processed
    func runControllers(drain: Bool = false) {
        while !pendingEvents.isEmpty {
            runControllers(pendingEvents.removeFirst())
            if !drain {
                break
            }
        }
    }
    
    /// Run each train controller on the specified train event
    /// - Parameter event: the train event
    func runControllers(_ event: TrainEvent) {
        let result = run(event)
        if result.events.count > 0 {
            // As long as something has changed in the layout processing,
            // make sure to run the controllers again so the layout can
            // be further updated (ie a feedback change might cause a train
            // to further stop or start).
            pendingEvents.append(contentsOf: result.events)
            DispatchQueue.main.async {
                self.runControllers()
            }
        }
        redrawSwitchboard()
    }
        
    private func run(_ event: TrainEvent) -> TrainHandlerResult {
        if let runtimeError = layout.runtimeError {
            BTLogger.router.error("⚙ Cannot evaluate the layout because there is a runtime error: \(runtimeError, privacy: .public)")
            return .none()
        }
        BTLogger.router.debug("⚙ Evaluating the layout for '\(event, privacy: .public)'")

        // Process the latest changes
        updateControllers()
                
        // Run each controller one by one, using
        // the sorted keys to ensure they always
        // run in the same order.
        let result = TrainHandlerResult()
        do {
            // Update and detect any unexpected feedbacks
            try updateExpectedFeedbacks()
            
            // Purge any invalid restart timers
            purgeRestartTimers()
            
            // Run each controller, one for each train, in order
            // to process the new state of each train (speed, position,
            // reserved blocks, etc).
            for train in layout.trains {
                result.append(try run(train: train, event: event))
            }
            
            // Update and detect any unexpected feedbacks
            // Note: it is necessary to repeat this step after
            // running all the train controllers because a train
            // might have moved and hence the expected feedbacks
            // should be updated promptly to reflect the new state.
            try updateExpectedFeedbacks()
        } catch {
            // Stop everything in case there is a problem processing the layout
            BTLogger.router.error("Stopping all trains because there is an error processing the layout: \(error.localizedDescription, privacy: .public)")
            layout.runtimeError = error.localizedDescription
            dumpAll()
            haltAll()
        }

        debugger.record(layoutController: self)
        
        return result
    }
        
    /// This is the main method to call to manage the train associated with this controller.
    ///
    /// This method executs all the handlers interested in the specified event and return the result which might
    /// contain more events to further process. The ``LayoutController`` is responsible to call this class
    /// again until all the events are processed.
    /// - Parameter event: the event to process
    /// - Returns: the result of the event processing
    private func run(train: Train, event: TrainEvent) throws -> TrainHandlerResult {
        let result = TrainHandlerResult()
        
        BTLogger.router.debug("\(train, privacy: .public): evaluating event '\(String(describing: event), privacy: .public)' for \(String(describing: train.scheduling), privacy: .public)")

        if train.scheduling == .unmanaged {
            result.append(try TrainHandlerUnmanaged.process(layout: layout, executor: self, train: train, event: event))
        } else {
            // Stop the train if there is no route associated with it
            guard let route = layout.route(for: train.routeId, trainId: train.id) else {
                stop(train: train)
                return result
            }

            result.append(try TrainHandlerManaged.process(layout: layout, reservation: reservation, executor: self, route: route, train: train, event: event))
        }

        if result.events.isEmpty {
            BTLogger.router.debug("\(train, privacy: .public): no resulting events")
        } else {
            BTLogger.router.debug("\(train, privacy: .public): resulting events are \(String(describing: result.events), privacy: .public)")
        }

        return result
    }

    private func updateExpectedFeedbacks() throws {
        if layout.detectUnexpectedFeedback {
            try feedbackMonitor.update(with: layout.trains)
            switchboard?.context.expectedFeedbackIds = feedbackMonitor.expectedFeedbacks
            try feedbackMonitor.handleUnexpectedFeedbacks()
        } else {
            switchboard?.context.expectedFeedbackIds = nil
        }
    }
    
    private func haltAll() {
        stopAll(includingManualTrains: true)
        
        // Send the command to zero the speed of each train
        // because the run() method won't run until the runtimeError
        // is cleared by the user. We want to make sure the train don't
        // start again if the user re-enable the layout manually.
        for train in layout.trains {
            setTrainSpeed(train, SpeedStep(value: 0))
            train.scheduling = .unmanaged
        }
        
        // Stop the Digital Controller to ensure nothing moves further
        stop() { }

        // Invalidate every restart timer
        pausedTrainTimers.forEach { $0.value.invalidate() }
        pausedTrainTimers.removeAll()        
    }
    
    // MARK: Commands
    
    func go(onCompletion: @escaping CompletionBlock) {
        interface.execute(command: .go(), onCompletion: onCompletion)
    }

    func stop(onCompletion: @escaping CompletionBlock) {
        interface.execute(command: .stop(), onCompletion: onCompletion)
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
    
    func stop(train: Train) {
        train.scheduling = .stopManaged
        runControllers(.schedulingChanged)
    }

    func stopAll(includingManualTrains: Bool) {
        let trains: [Train]
        if includingManualTrains {
            trains = layout.trains
        } else {
            trains = layout.trainsThatCanBeStopped()
        }
        for train in trains {
            stop(train: train)
        }
    }

    func finish(train: Train) {
        train.scheduling = .finishManaged
        runControllers(.schedulingChanged)
    }
    
    func finishAll() {
        for train in layout.trainsThatCanBeFinished() {
            finish(train: train)
        }
    }

    // MARK: Paused Train Management
    
    // A map that contains all trains that are currently paused
    // and need to be restarted at a later time. Each train
    // has an associated timer that fires when it is time to
    // restart the train
    var pausedTrainTimers = [Identifier<Train>:Timer]()

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
        pausedTrainTimers = pausedTrainTimers.filter({$0.value.isValid})
    }
    
    func restartTimerFired(_ train: Train) {
        train.timeUntilAutomaticRestart = 0
        runControllers(.restartTimerExpired(train: train))
    }
    
    private func redrawSwitchboard() {
        switchboard?.state.triggerRedraw.toggle()
    }
}

extension LayoutController {
    
    // TODO: can we use Route and Train instance directly?
    func start(routeID: Identifier<Route>, trainID: Identifier<Train>, destination: Destination? = nil) throws {
        guard let route = layout.route(for: routeID, trainId: trainID) else {
            throw LayoutError.routeNotFound(routeId: routeID)
        }
        
        guard let train = layout.train(for: trainID) else {
            throw LayoutError.trainNotFound(trainId: trainID)
        }
        
        guard let blockId = train.blockId else {
            throw LayoutError.trainNotAssignedToABlock(train: train)
        }
        
        guard let block = layout.block(for: blockId), block.train != nil else {
            throw LayoutError.trainNotFoundInBlock(blockId: blockId)
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
            route.steps.removeAll()
        } else {
            // Check to make sure the train is somewhere along the route
            train.routeStepIndex = -1
            for (index, step) in route.steps.enumerated() {
                guard let (blockId, direction) = layout.block(for: train, step: step) else {
                    continue
                }
                
                guard train.blockId == blockId else {
                    continue
                }
                
                guard let block = layout.block(for: train.blockId) else {
                    continue
                }

                guard let trainInstance = block.train else {
                    continue
                }
                
                // Check that the train direction matches as well.
                if trainInstance.direction == direction {
                    train.routeStepIndex = index
                    break
                }
            }
                                 
            guard train.routeStepIndex >= 0 else {
                throw LayoutError.trainNotFoundInRoute(train: train, route: route)
            }
        }

        train.scheduling = .managed
        runControllers(.schedulingChanged)
    }
    
    /// Send a turnout state command
    ///
    /// - Parameters:
    ///   - turnout: the turnout whose state need to be sent to the Digital Controller
    ///   - completion: completion block called when the command has been sent
    func sendTurnoutState(turnout: Turnout, completion: @escaping CompletionBlock) {
        turnout.actualStateReceived = false
        executor.sendTurnoutState(turnout: turnout, completion: completion)
    }
    
    /// Send a train direction command
    ///
    /// - Parameters:
    ///   - train: the train to change the direction
    ///   - forward: true for forward direction, false for backward direction
    ///   - completion: completion block called when the command has been sent
    func sendTrainDirection(train: Train, forward: Bool, completion: @escaping CompletionBlock) {
        BTLogger.router.debug("\(train, privacy: .public): change train direction to \(forward)")
        executor.sendTrainDirection(train: train, forward: forward, completion: completion)
    }
    
    func setTrainSpeed(_ train: Train, _ speed: TrainSpeed.UnitKph, speedLimit: Bool = true, force: Bool = false, acceleration: TrainSpeedAcceleration.Acceleration? = nil, completion: CompletionCancelBlock? = nil) {
        if speedLimit {
            let route = layout.route(for: train.routeId, trainId: train.id)
            train.speed.requestedKph = min(speed, reservation.maximumSpeedAllowed(train: train, route: route))
        } else {
            train.speed.requestedKph = speed
        }
        setTrainSpeed(train, train.speed.requestedSteps, acceleration: acceleration, completion: completion)
    }

    func setTrainSpeed(_ train: Train, _ speed: SpeedStep, acceleration: TrainSpeedAcceleration.Acceleration? = nil, completion: CompletionCancelBlock? = nil) {
        train.speed.requestedSteps = speed
        // Note: always send the train speed request, even if the train already runs at the specified
        // speed because we need the TrainSpeedManager to ultimately make any optimization decision
        // (for example, if a speed change is in progress but hasn't had a change to change the speed
        // yet, we might think we don't need to send another train speed change request. But this is incorrect
        // because if we don't do that, the previous speed change request will continue to execute while
        // it is not our intention).
        // TODO: executor not used? Should we refactor how this is done?
        if let controller = speedManagers[train.id] {
            controller.changeSpeed(acceleration: acceleration) { completed in
                completion?(completed)
            }
        } else {
            assertionFailure("There is no TrainSpeedManager for \(train.name)")
            BTLogger.router.error("There is no TrainSpeedManager for \(train.name, privacy: .public)")
            completion?(false)
        }
    }

    // Set the direction of travel of the locomotive
    func setLocomotiveDirection(_ train: Train, forward: Bool, completion: CompletionBlock? = nil) {
        if train.directionForward != forward {
            sendTrainDirection(train: train, forward: forward) {
                completion?()
            }
        } else {
            completion?()
        }
    }
    
    /// Set the position of a train within the current block
    ///
    /// - Parameters:
    ///   - train: the train
    ///   - position: the position of the train within its block
    ///   - removeLeadingBlocks: true to remove the leading blocks (by default), false to keep the leading blocks
    func setTrainPosition(_ train: Train, _ position: Int, removeLeadingBlocks: Bool = true) throws {
        train.position = position
        
        if removeLeadingBlocks {
            try reservation.removeLeadingBlocks(train: train)
        }
    }
    
    // Toggle the direction of the train within the block itself
    func toggleTrainDirectionInBlock(_ train: Train) throws {
        guard let blockId = train.blockId else {
            throw LayoutError.trainNotAssignedToABlock(train: train)
        }
        
        guard let block = layout.block(for: blockId) else {
            throw LayoutError.blockNotFound(blockId: blockId)
        }

        guard let ti = block.train else {
            throw LayoutError.trainNotFoundInBlock(blockId: blockId)
        }

        guard ti.trainId == train.id else {
            throw LayoutError.trainInBlockDoesNotMatch(trainId: train.id, blockId: blockId, blockTrainId: ti.trainId)
        }

        block.train = TrainInstance(train.id, ti.direction.opposite)
        train.wagonsPushedByLocomotive.toggle()

        try reservation.removeLeadingBlocks(train: train)
    }
        
    /// Sets a train to a specific block.
    ///
    /// - Parameters:
    ///   - trainId: the train
    ///   - toBlockId: the block in which to put the train
    ///   - position: the position in the block in which to put the train
    ///   - direction: the direction in the block in which to put the train
    ///   - routeIndex: optional index in the route
    ///   - removeLeadingBlocks: true to remove the leading blocks (by default), false to keep the leading blocks
    func setTrainToBlock(_ train: Train, _ toBlockId: Identifier<Block>, position: Position = .start, direction: Direction, routeIndex: Int? = nil, removeLeadingBlocks: Bool = true) throws {
        try layout.setTrainToBlock(train.id, toBlockId, position: position, direction: direction, routeIndex: routeIndex)
        if removeLeadingBlocks {
            try reservation.removeLeadingBlocks(train: train)
        }
    }
}

extension LayoutController: MetricsProvider {
    
    var metrics: [Metric] {
        executor.metrics + interface.metrics
    }

}

extension LayoutCommandExecutor: MetricsProvider {
    
    var metrics: [Metric] {
        [.init(id: turnoutQueue.name, value: String(turnoutQueue.scheduledCount))]
    }

}
