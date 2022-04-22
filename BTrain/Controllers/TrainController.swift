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

protocol TrainControllerDelegate: AnyObject {
    func scheduleRestartTimer(train: Train)
}

/**
 This class manages a single train in the layout. It relies on a set of handler classes to manage the starting, stopping and monitoring of the train movement inside blocks.
 
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
    
    /// The layout associated with this controller
    let layout: Layout
    
    /// The train managed by this controller
    let train: Train
    
    // The train acceleration controller instance that is monitoring the specified train
    // by sending the actual speed to the Digital Controller.
    let accelerationController: TrainControllerAcceleration
    
    weak var delegate: TrainControllerDelegate?
            
    /// The array of handlers when the train runs in automatic scheduling mode
    private var automaticSchedulingHandlers = [TrainAutomaticSchedulingHandler]()
    
    /// The array of handlers when the train runs in manual scheduling mode
    private var manualSchedulingHandlers = [TrainManualSchedulingHandler]()

    init(layout: Layout, train: Train, interface: CommandInterface, delegate: TrainControllerDelegate? = nil) {
        self.layout = layout
        self.train = train
        self.accelerationController = TrainControllerAcceleration(train: train, interface: interface)
        self.delegate = delegate
        
        registerHandlers()
    }
                        
    private func registerHandlers() {
        automaticSchedulingHandlers.append(TrainStartHandler())
        automaticSchedulingHandlers.append(TrainMoveWithinBlockHandler())
        automaticSchedulingHandlers.append(TrainMoveToNextBlockHandler())
        automaticSchedulingHandlers.append(TrainDetectStopHandler())
        automaticSchedulingHandlers.append(TrainExecuteStopInBlockHandler())
        automaticSchedulingHandlers.append(TrainSpeedLimitEventHandler())
        automaticSchedulingHandlers.append(TrainReserveLeadingBlocksHandler())
        automaticSchedulingHandlers.append(TrainStopPushingWagonsHandler())

        manualSchedulingHandlers.append(TrainStateHandler())
        manualSchedulingHandlers.append(TrainMoveWithinBlockHandler())
        manualSchedulingHandlers.append(TrainManualMoveToNextBlockHandler())
        manualSchedulingHandlers.append(TrainManualStopTriggerDetectionHandler())
    }
        
    /// This is the main method to call to manage the train associated with this controller.
    ///
    /// This method executs all the handlers interested in the specified event and return the result which might
    /// contain more events to further process. The ``LayoutController`` is responsible to call this class
    /// again until all the events are processed.
    /// - Parameter event: the event to process
    /// - Returns: the result of the event processing
    func run(_ event: TrainEvent) throws -> TrainHandlerResult {
        var result: TrainHandlerResult = .none()
        
        BTLogger.debug("* Evaluating \(train) for \(event) and \(train.scheduling)")
        
        if train.automaticScheduling {
            // Stop the train if there is no route associated with it
            guard let route = layout.route(for: train.routeId, trainId: train.id) else {
                return try stop()
            }
            
            let interestedHandlers = automaticSchedulingHandlers.filter({ $0.events.contains(event) })
            for handler in interestedHandlers {
                BTLogger.debug("* \(handler) for \(train)")
                result = result.appending(try handler.process(layout: layout, train: train, route: route, event: event, controller: self))
            }
        } else {
            let interestedHandlers = manualSchedulingHandlers.filter({ $0.events.contains(event) })
            for handler in interestedHandlers {
                BTLogger.debug("* \(handler) for \(train)")
                result = result.appending(try handler.process(layout: layout, train: train, event: event, controller: self))
            }
        }

        BTLogger.debug("* Resulting events: \(result.events) for \(train)")

        return result
    }
    
    /// Stop the train by setting its speed to 0.
    ///
    /// - Parameter completely: true if the train stops completely, false otherwise. A train that stops completely will have its ``Train/scheduling`` changed to ``Train/Schedule/manual``.
    /// - Returns: the result
    func stop(completely: Bool = false) throws -> TrainHandlerResult {
        train.stopTrigger = nil
                                
        BTLogger.debug("Stop train \(train)")
        
        try layout.stopTrain(train.id, completely: completely) { }
                
        return .none()
    }
            
    /// This method tries to reserve the leading blocks for the train. If the blocks cannot be reserved and the route is automatic,
    /// the route is updated and the leading blocks reserved again.
    ///
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
        
        BTLogger.debug("Generating a new route for \(train) at block \(currentBlock.name) because the next blocks could not be reserved (route: \(route.steps.debugDescription))")

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
            BTLogger.debug("Generated route is: \(route.steps)")
            return true
        } else {
            BTLogger.warning("Unable to find a suitable route for train \(train)")
            return false
        }
    }
    
}
