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
final class LayoutController: TrainControllerDelegate {
    
    // The layout being managed
    let layout: Layout
    
    // A helper class that monitors feedbacks
    let feedbackMonitor: LayoutFeedbackMonitor
    
    // The interface to the Digital Controller
    var interface: CommandInterface
        
    // The switchboard state, used to refresh the switchboard
    // when certain events happen in the layout controller
    let switchboard: SwitchBoard?
    
    // An ordered map of train controller for each available train.
    // The train controller manages a single train in the layout.
    // Note: we need an ordered map in order to have predictable outcome
    // at runtime and during unit testing.
    private var controllers = OrderedDictionary<Identifier<Train>, TrainController>()

    // The executor that will send commands to the Digital Controller
    private var executor: LayoutCommandExecutor
    
    // Retain the sink to observe any change to the layout
    private var layoutChangeSink: AnyCancellable?

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
        registerForSpeedChange()
        registerForDirectionChange()
        registerForTurnoutChange()
    }
    
    func updateControllers() {
        for train in layout.trains {
            if controllers[train.id] == nil {
                controllers[train.id] = TrainController(layout: layout, train: train, interface: interface, delegate: self)
            }
        }

        // Remove controllers that don't belong to an existing train
        controllers = controllers.filter({ element in
            return layout.train(for: element.key) != nil
        })
    }

    func runControllers(_ event: TrainEvent) {
        let result = run(event)
        if result.events.count > 0 {
            // As long as something has changed in the layout processing,
            // make sure to run the controllers again so the layout can
            // be further updated (ie a feedback change might cause a train
            // to further stop or start).
            for event in result.events {
                runControllers(event)
            }
        }
        redrawSwitchboard()
    }
        
    private func run(_ event: TrainEvent) -> TrainHandlerResult {
        if let runtimeError = layout.runtimeError {
            BTLogger.controller.error("⚙ Cannot evaluate the layout because there is a runtime error: \(runtimeError, privacy: .public)")
            return .none()
        }
        BTLogger.controller.debug("⚙ Evaluating the layout for \(event.rawValue, privacy: .public)")

        // Process the latest changes
        updateControllers()
                
        // Run each controller one by one, using
        // the sorted keys to ensure they always
        // run in the same order.
        var result: TrainHandlerResult = .none()
        do {
            // Update and detect any unexpected feedbacks
            try updateExpectedFeedbacks()
            
            // Purge any invalid restart timers
            purgeRestartTimers()
            
            // Run each controller, one for each train, in order
            // to process the new state of each train (speed, position,
            // reserved blocks, etc).
            for controller in controllers.values {
                result = result.appending(try controller.run(event))
            }
            
            // Update and detect any unexpected feedbacks
            // Note: it is necessary to repeat this step after
            // running all the train controllers because a train
            // might have moved and hence the expected feedbacks
            // should be updated promptly to reflect the new state.
            try updateExpectedFeedbacks()
        } catch {
            // Stop everything in case there is a problem processing the layout
            BTLogger.controller.error("Stopping all trains because there is an error processing the layout: \(error.localizedDescription, privacy: .public)")
            layout.runtimeError = error.localizedDescription
            dumpAll()
            haltAll()
        }

        debugger.record(layoutController: self, controllers: controllers.values.elements)
        
        return result
    }
        
    private func updateExpectedFeedbacks() throws {
        if layout.detectUnexpectedFeedback {
            try feedbackMonitor.update(with: controllers.values.map { $0.train })
            switchboard?.context.expectedFeedbackIds = feedbackMonitor.expectedFeedbacks
            try feedbackMonitor.handleUnexpectedFeedbacks()
        } else {
            switchboard?.context.expectedFeedbackIds = nil
        }
    }
    
    private func haltAll() {
        do {
            try stopAll(includingManualTrains: true)
        } catch {
            BTLogger.controller.error("Unable to stop all the trains because \(error.localizedDescription, privacy: .public)")
        }
        
        // Stop the Digital Controller to ensure nothing moves further
        stop() { }

        // Invalidate every restart timer
        pausedTrainTimers.forEach { $0.value.invalidate() }
        pausedTrainTimers.removeAll()        
    }
    
    // MARK: Commands
    
    func go(onCompletion: @escaping () -> Void) {
        interface.execute(command: .go(), onCompletion: onCompletion)
    }

    func stop(onCompletion: @escaping () -> Void) {
        interface.execute(command: .stop(), onCompletion: onCompletion)
    }
    
    func start(routeID: Identifier<Route>, trainID: Identifier<Train>, destination: Destination?) throws {
        try layout.start(routeID: routeID, trainID: trainID, destination: destination)
        runControllers(.schedulingChanged)
    }
    
    func startAll() {
        for train in layout.trainsThatCanBeStarted() {
            if let routeId = train.routeId {
                do {
                    try start(routeID: routeId, trainID: train.id, destination: nil)
                } catch {
                    BTLogger.controller.error("Unable to start \(train.name): \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }
    
    func stop(trainID: Identifier<Train>, completely: Bool) throws {
        try layout.stopTrain(trainID, completely: completely) { }
        runControllers(.schedulingChanged)
    }

    func stopAll(includingManualTrains: Bool) throws {
        let trains: [Train]
        if includingManualTrains {
            trains = layout.trains
        } else {
            trains = layout.trainsThatCanBeStopped()
        }
        for train in trains {
            do {
                try stop(trainID: train.id, completely: true)
            } catch {
                BTLogger.controller.error("Unable to stop \(train.name): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func finish(trainID: Identifier<Train>) throws {
        try layout.finishTrain(trainID)
        runControllers(.schedulingChanged)
    }
    
    func finishAll() throws {
        for train in layout.trainsThatCanBeFinished() {
            try finish(trainID: train.id)
        }
    }

    // MARK: Paused Train Management
    
    // A map that contains all trains that are currently paused
    // and need to be restarted at a later time. Each train
    // has an associated timer that fires when it is time to
    // restart the train
    var pausedTrainTimers = [Identifier<Train>:Timer]()
    
    // This method is called by the TrainController (via its delegate)
    // when a train has stopped in a station and needs to be restarted later on.
    func scheduleRestartTimer(train: Train) {
        guard train.timeUntilAutomaticRestart > 0 else {
            return
        }
        
        // Start a timer that will restart the train with a new automatic route
        // Note: the timer fires every second to update the remaining time until it reaches 0.
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] timer in
            train.timeUntilAutomaticRestart -= 1
            if train.timeUntilAutomaticRestart <= 0 {
                BTLogger.controller.debug("It is now time to restart train \(train, privacy: .public)")
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
        runControllers(.restartTimerExpired)
    }
    
    private func redrawSwitchboard() {
        switchboard?.state.triggerRedraw.toggle()
    }
}

extension LayoutController: LayoutCommandExecuting {
    
    func sendTurnoutState(turnout: Turnout, completion: @escaping CompletionBlock) {
        executor.sendTurnoutState(turnout: turnout, completion: completion)
    }
    
    func sendTrainDirection(train: Train, completion: @escaping CompletionBlock) {
        executor.sendTrainDirection(train: train, completion: completion)
    }
    
    func sendTrainSpeed(train: Train, acceleration: TrainSpeedAcceleration.Acceleration?, completion: @escaping CompletionBlock) {
        if let controller = controllers[train.id] {
            controller.accelerationController.changeSpeed(of: train, acceleration: acceleration, completion: completion)
        } else {
            assertionFailure("There is no TrainController for \(train.name)")
            BTLogger.controller.error("There is no TrainController for \(train.name, privacy: .public)")
            completion()
        }
    }
    
}
