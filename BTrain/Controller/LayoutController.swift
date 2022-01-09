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

final class LayoutController: ObservableObject {
    
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
                
        registerForFeedbackChanges()
        registerForTrainBlockChanges()
        
        updateControllers()
    }
    
    // Make sure to debounce all the changes so they don't overwhelm
    // the system and also to ensure they don't end up in a re-entrant
    // loop that will crash the app.
    let debounceFor: RunLoop.SchedulerTimeType.Stride = .milliseconds(100)
    
    func registerForFeedbackChanges() {
        // TODO: use LayoutObserver
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

    func updateControllers() {
        for train in layout.trains {
            if controllers[train.id] == nil {
                controllers[train.id] = TrainController(layout: layout, train: train)
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
            
            for controller in sortedControllers {
                if try controller.run() == .processed {
                    result = .processed
                }
            }
        } catch {
            // Stop the train in case there is a problem processing the layout
            layout.runtimeError = error.localizedDescription
            BTLogger.error("Stopping all trains because there is an error processing the layout: \(error.localizedDescription)")
            stopAll()
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
    
    func start(routeID: Identifier<Route>, trainID: Identifier<Train>, toBlockId: Identifier<Block>?) throws {
        try layout.start(routeID: routeID, trainID: trainID, toBlockId: toBlockId)
        _ = run()
    }
    
    func stop(routeID: Identifier<Route>, trainID: Identifier<Train>) throws {
        try layout.free(trainID: trainID)
        try layout.stop(routeID: routeID, trainID: trainID)
        _ = run()
    }
    
    func discoverLocomotives() {
        guard let interface = interface else {
            return
        }

        interface.queryLocomotives(command: .locomotives()) { locomotives in
            self.layout.freeAllTrains(removeFromLayout: true)

            let trains: [Train] = locomotives.map { loc in
                let train = Train()
                if let name = loc.name {
                    train.name = name
                }
                if let address = loc.commandAddress {
                    train.address = address
                }
                return train
            }
            self.layout.trains = trains
        }
    }
}
