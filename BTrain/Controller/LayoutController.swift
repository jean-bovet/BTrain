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

final class LayoutController: ObservableObject, TrainControllerDelegate {
    
    let layout: Layout
    
    let feedbackMonitor: LayoutFeedbackMonitor
    
    var interface: CommandInterface?
        
    var controllers = [Identifier<Train>:TrainController]()

    var sortedControllers: [TrainController] {
        let sortedKeys = controllers.keys.sorted()
        return sortedKeys.compactMap { controllers[$0] }
    }
    
    var cancellables = [AnyCancellable]()
        
    init(layout: Layout, interface: CommandInterface?) {
        self.layout = layout
        self.feedbackMonitor = LayoutFeedbackMonitor(layout: layout)
        self.interface = interface
                
        // TODO: what happens when an element is added/removed? Are these change blocks updated accordingly?
        registerForFeedbackChanges()
        registerForTrainBlockChanges()
        
        updateControllers()
    }
        
    func registerForFeedbackChanges() {
        for feedback in layout.feedbacks {
            let cancellable = feedback.$detected
                .dropFirst()
                .removeDuplicates()
                .receive(on: RunLoop.main)
                .sink { value in
                    BTLogger.debug("Feedback \(feedback) changed to \(feedback.detected)")
                    self.runControllers()
                }
            cancellables.append(cancellable)
        }
    }
    
    func registerForTrainBlockChanges() {
        for train in layout.trains {
            let cancellable = train.$blockId
                .dropFirst()
                .removeDuplicates()
                .receive(on: RunLoop.main)
                .sink { value in
                    self.runControllers()
                }
            cancellables.append(cancellable)
        }
    }

    var pausedTrainTimers = [Identifier<Train>:Timer]()
    
    func scheduleRestartTimer(trainInstance: Block.TrainInstance) {
        guard let time = trainInstance.restartDelayTime, time > 0 else {
            return
        }
        
        // Start a timer that will restart the train with a new automatic route
        let timer = Timer.scheduledTimer(withTimeInterval: time, repeats: false, block: { timer in
            BTLogger.debug("Timer fired to restart train \(trainInstance.trainId)")
            trainInstance.restartDelayTime = 0
            timer.invalidate()
            self.runControllers()
        })
        pausedTrainTimers[trainInstance.trainId] = timer
    }

    func restartControllers() throws -> TrainController.Result {
        var result = TrainController.Result.none
        for controller in self.sortedControllers {
            if let block = layout.block(for: controller.train.id), let ti = block.train, ti.restartDelayTime == 0 {
                BTLogger.debug("Restarting train \(ti.trainId)")
                ti.restartDelayTime = nil
                try controller.restartTrain()
                result = .processed
            }
        }
        cleanupRestartTimer()
        return result
    }
    
    func cleanupRestartTimer() {
        // Remove any expired timer
        // TODO: when stopping a train manually, invalidate any timer related to that train!
        pausedTrainTimers = pausedTrainTimers.filter({$0.value.isValid})
    }
    
    func updateControllers() {
        for train in layout.trains {
            if controllers[train.id] == nil {
                controllers[train.id] = TrainController(layout: layout, train: train, delegate: self)
            }
        }

        // Remove controllers that don't belong to an existing train
        controllers = controllers.filter({ element in
            return layout.train(for: element.key) != nil
        })
    }

    func runControllers() {
        if run() == .processed {
            // As long as something has changed in the layout processing,
            // make sure to run the controllers again so the layout can
            // be further updated (ie a feedback change might cause a train
            // to further stop or start).
            DispatchQueue.main.async {
                self.runControllers()
            }
        }
    }
    
    func run() -> TrainController.Result {
        // Make sure to send a signal when the coordinator changes
        // so observer can update accordingly.
        objectWillChange.send()
        
        // Process the latest changes
        updateControllers()
                
        // Run each controller one by one, using
        // the sorted keys to ensure they always
        // run in the same order.
        let sortedControllers = sortedControllers
        var result: TrainController.Result = .none
        do {
            // Update and detect any unexpected feedbacks
            if layout.detectUnexpectedFeedback {
                try feedbackMonitor.update(with: sortedControllers.map { $0.train })
                try feedbackMonitor.handleUnexpectedFeedbacks()
            }
            
            // Restart any train that have waited long enough in their station with automatic routing
            if try restartControllers() == .processed {
                result = .processed
            }
            
            // Run each controller
            for controller in sortedControllers {
                if try controller.run() == .processed {
                    result = .processed
                }
            }
        } catch {
            // Stop the train in case there is a problem processing the layout
            layout.runtimeError = error.localizedDescription
            BTLogger.error("Stopping all trains because there is an error processing the layout: \(error.localizedDescription)")
            // TODO: ensure TrainController does not run anymore when a stop has been issued. Only an explicit Start from the user is allowed to change that state back (for safety reason)
            stopAll()
//            stop() {
//                self.stopAll()
//            }
        }
        return result
    }
        
    func stopAll() {
        for controller in sortedControllers {
            do {
                try layout.stopTrain(controller.train)
            } catch {
                BTLogger.error("Unable to stop train \(controller.train) because \(error.localizedDescription)")
            }
        }
    }
    
    func stop(onCompletion: @escaping () -> Void) {
        interface?.execute(command: .stop(), onCompletion: onCompletion)
    }
    
    func start(routeID: Identifier<Route>, trainID: Identifier<Train>, toBlockId: Identifier<Block>?) throws {
        try layout.start(routeID: routeID, trainID: trainID, toBlockId: toBlockId)
        _ = run()
    }
    
    func stop(routeID: Identifier<Route>, trainID: Identifier<Train>) throws {
        try layout.free(trainID: trainID)
        try layout.stop(routeID: routeID, trainID: trainID)
        _ = run()
    }
    
    func discoverLocomotives(merge: Bool) {
        guard let interface = interface else {
            return
        }

        interface.queryLocomotives(command: .locomotives()) { locomotives in
            self.process(locomotives: locomotives, merge: merge)
        }
    }
    
    func process(locomotives: [CommandLocomotive], merge: Bool) {
        var newTrains = [Train]()
        for loc in locomotives {
            if let locUID = loc.uid, let train = layout.trains.first(where: { $0.id.uuid == String(locUID) }), merge {
                mergeLocomotive(loc, with: train)
            } else if let locAddress = loc.address, let train = layout.trains.find(address: locAddress, decoder: loc.decoderType), merge {
                mergeLocomotive(loc, with: train)
            } else {
                let train: Train
                if let locUID = loc.uid {
                    train = Train(uuid: String(locUID))
                } else {
                    train = Train()
                }
                mergeLocomotive(loc, with: train)
                newTrains.append(train)
            }
        }
        
        if merge {
            layout.trains.append(contentsOf: newTrains)
        } else {
            layout.freeAllTrains(removeFromLayout: true)
            layout.trains = newTrains
        }
    }
    
    func mergeLocomotive(_ locomotive: CommandLocomotive, with train: Train) {
        if let name = locomotive.name {
            train.name = name
        }
        if let address = locomotive.address {
            train.address = address
        }
        if let maxSpeed = locomotive.maxSpeed {
            train.speed.maxSpeed = TrainSpeed.UnitKph(maxSpeed)
        }
        train.decoder = locomotive.decoderType
    }
}
