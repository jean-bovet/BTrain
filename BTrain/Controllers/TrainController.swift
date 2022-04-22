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
import OrderedCollections

protocol TrainControllerDelegate: AnyObject {
    func scheduleRestartTimer(train: Train)
}

/**
 This class manages a single train in the layout. It takes care of starting and stopping it, monitoring
 feedbacks when it moves inside a block or from one block to another, etc.
 
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
final class TrainController {
    
    // Most method in this class returns a result
    // that indicates if that method has done something
    // or not. This is useful information that will help
    // the LayoutController to re-run the TrainController
    // in case there are any changes to be applied.
    struct Result {
        let events: [TrainEvent]

        static func none() -> Result {
            .init(events: [])
        }

        static func one(_ event: TrainEvent) -> Result {
            .init(events: [event])
        }
        
        func appending(_ event: TrainEvent) -> Result {
            .init(events: self.events + [event])
        }
        
        func appending(_ result: Result) -> Result {
            .init(events: self.events + result.events)
        }
    }
        
    let layout: Layout
    let train: Train
    
    // The train acceleration controller instance that is monitoring the specified train
    // by sending the actual speed to the Digital Controller.
    let accelerationController: TrainControllerAcceleration
    
    weak var delegate: TrainControllerDelegate?
        
    var automaticRouteHandlers = [TrainAutomaticRouteHandling]()
    var manualRouteHandlers = [TrainManualRouteHandling]()

    init(layout: Layout, train: Train, interface: CommandInterface, delegate: TrainControllerDelegate? = nil) {
        self.layout = layout
        self.train = train
        self.accelerationController = TrainControllerAcceleration(train: train, interface: interface)
        self.delegate = delegate
        
        automaticRouteHandlers.append(TrainStartHandler())
        automaticRouteHandlers.append(TrainMoveWithinBlockHandler())
        automaticRouteHandlers.append(TrainMoveToNextBlockHandler())
        automaticRouteHandlers.append(TrainDetectStopHandler())
        automaticRouteHandlers.append(TrainExecuteStopInBlockHandler())
        automaticRouteHandlers.append(TrainSpeedLimitEventHandler())
        automaticRouteHandlers.append(TrainReserveLeadingBlocksHandler())
        automaticRouteHandlers.append(TrainStopPushingWagonsHandler())

        manualRouteHandlers.append(TrainStateHandler())
        manualRouteHandlers.append(TrainManualMoveToNextBlockHandler())
        manualRouteHandlers.append(TrainManualStopTriggerDetectionHandler())
    }
                        
    // This is the main method to call to manage the changes for the train.
    // If this method returns Result.processed, it is expected to be called again
    // in order to process any changes remaining.
    // Note: because each function below has a side effect that can affect
    // the currentBlock and nextBlock (as well as the train speed and other parameters),
    // always have each function retrieve what it needs.
    @discardableResult
    func run(_ event: TrainEvent) throws -> Result {
        var result: Result = .none()
        
        BTLogger.debug("* Evaluating \(train) for \(event) and \(train.scheduling)")
        
        if train.automaticScheduling {
            // Stop the train if there is no route associated with it
            guard let route = layout.route(for: train.routeId, trainId: train.id) else {
                return try stop()
            }
            
            let interestedHandlers = automaticRouteHandlers.filter({ $0.events.contains(event) })
            for handler in interestedHandlers {
                BTLogger.debug("* \(handler) for \(train)")
                result = result.appending(try handler.process(layout: layout, train: train, route: route, event: event, controller: self))
            }
        } else {
            let interestedHandlers = manualRouteHandlers.filter({ $0.events.contains(event) })
            for handler in interestedHandlers {
                BTLogger.debug("* \(handler) for \(train)")
                result = result.appending(try handler.process(layout: layout, train: train, event: event, controller: self))
            }
        }

        BTLogger.debug("* Resulting events: \(result.events) for \(train)")

        return result
    }
    
    func stop(completely: Bool = false) throws -> Result {
        train.stopTrigger = nil
                                
        debug("Stop train \(train)")
        
        try layout.stopTrain(train.id, completely: completely) { }
                
        return .none()
    }
            
    /// This method tries to reserve the leading blocks for the train. If the blocks cannot be reserved and the route is automatic,
    /// the route is updated and the leading blocks reserved again.
    /// - Parameters:
    ///   - route: the route
    ///   - currentBlock: the current block
    ///   - trainStarting: true if the train is starting, defaults to false
    /// - Returns: true if the leading blocks could be reserved, false otherwise.
    func reserveLeadBlocks(route: Route, currentBlock: Block, trainStarting: Bool = false) throws -> Bool {
        if try layout.reservation.updateReservedBlocks(train: train, trainStarting: trainStarting) {
            return true
        }
        
        guard route.automatic else {
            return false
        }
        
        debug("Generating a new route for \(train) at block \(currentBlock.name) because the next blocks could not be reserved (route: \(route.steps.debugDescription))")

        // Update the automatic route
        if try updateAutomaticRoute(for: train.id) {
            // And try to reserve the lead blocks again
            return try layout.reservation.updateReservedBlocks(train: train, trainStarting: trainStarting)
        } else {
            return false
        }
    }

    private func updateAutomaticRoute(for trainId: Identifier<Train>) throws -> Bool {
        let (success, route) = try layout.automaticRouting.updateAutomaticRoute(for: train.id)
        if success {
            debug("Generated route is: \(route.steps)")
            return true
        } else {
            BTLogger.warning("Unable to find a suitable route for train \(train)")
            return false
        }
    }
    
    func debug(_ message: String) {
        BTLogger.debug(message)
    }

}
