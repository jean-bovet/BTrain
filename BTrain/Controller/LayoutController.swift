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
    var interface: CommandInterface?
        
    // An ordered map of train controller for each available train.
    // The train controller manages a single train in the layout.
    // Note: we need an ordered map in order to have predictable outcome
    // at runtime and during unit testing.
    private var controllers = OrderedDictionary<Identifier<Train>, TrainController>()
    
    private var cancellables = [AnyCancellable]()
        
    init(layout: Layout, interface: CommandInterface?) {
        self.layout = layout
        self.feedbackMonitor = LayoutFeedbackMonitor(layout: layout)
        self.interface = interface
                        
        updateControllers()
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
        // Process the latest changes
        updateControllers()
                
        // Run each controller one by one, using
        // the sorted keys to ensure they always
        // run in the same order.
        let sortedControllers = controllers.values
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
            // Stop everything in case there is a problem processing the layout
            stopAll()
            layout.runtimeError = error.localizedDescription
            BTLogger.error("Stopping all trains because there is an error processing the layout: \(error.localizedDescription)")
        }
        return result
    }
        
    private func stopAll() {
        // Stop the Digital Controller to ensure nothing moves further
        stop() { }

        // Disable all the routes
        layout.routes.forEach { $0.enabled = false }

        // Invalidate every restart timer
        pausedTrainTimers.forEach { $0.value.invalidate() }
        pausedTrainTimers.removeAll()
        
        // Stop each train actively monitored by the controllers
        for controller in controllers.values {
            do {
                try layout.stopTrain(controller.train)
            } catch {
                BTLogger.error("Unable to stop train \(controller.train) because \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: Commands
    
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
    
    // MARK: Paused Train Management
    
    // A map that contains all trains that are currently paused
    // and need to be restarted at a later time. Each train
    // has an associated timer that fires when it is time to
    // restart the train
    var pausedTrainTimers = [Identifier<Train>:Timer]()
    
    // This method is called by the TrainController (via this class delegate)
    // when a train has stopped in a station and needs to be restarted later on.
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

    // This method is called by this class to restart any train that needs
    // to be restarted.
    func restartControllers() throws -> TrainController.Result {
        var result = TrainController.Result.none
        for controller in controllers.values {
            if let block = layout.block(for: controller.train.id), let ti = block.train, ti.restartDelayTime == 0 {
                BTLogger.debug("Restarting train \(ti.trainId)")
                ti.restartDelayTime = nil
                try controller.restartTrain()
                result = .processed
            }
        }
        // Remove any expired timer
        pausedTrainTimers = pausedTrainTimers.filter({$0.value.isValid})
        return result
    }
}
