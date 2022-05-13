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

/// This class handles the starting (or re-starting) of a train in an automatic scheduling mode.
final class TrainStartHandler: TrainAutomaticSchedulingHandler {
    
    var events: Set<TrainEvent> {
        [
            // React when the scheduling mode changes, which happens for example
            // when a train is started for the first time by request from the user.
            .schedulingChanged,
            
            // React when a train has moved to another block, because this means
            // that the train managed by this handler might be able to start or restart
            // as the blocks ahead might be free.
            .movedToNextBlock,
            
            // When the restart timer expires, this handler restarts the train
            .restartTimerExpired,
            
            // A train can stop in a block because no blocks can be reserved ahead.
            // But when it finally moves to the last part of the block, the block
            // ahead can be reserved (ie the tail of the train frees a turnout),
            // we want to make sure to restart it.
            .movedInsideBlock
        ]
    }

    func process(layout: Layout, train: Train, route: Route, event: TrainEvent, controller: TrainControlling) throws -> TrainHandlerResult {
        // Note: we also want to start a train that is braking to stop temporarily, which can happen
        // when the next block that was occupied (and caused the train to brake in the first place) becomes free.
        guard train.state == .stopped || (train.state == .braking && train.stateChangeRequest == .stopTemporarily) else {
            return .none()
        }

        guard let currentBlock = layout.currentBlock(train: train) else {
            return .none()
        }

        // Do not start the train if there is still time for the train until it has to restart
        guard train.timeUntilAutomaticRestart == 0 else {
            return .none()
        }
        
        // If the train was scheduled to finish, stop the train completely only when:
        // - The train has reached the last block of the route (it can happen that a train can
        // be stopped in the middle of the route if that route was blocked for some reason).
        // - The train route is empty because it could not be determined
        if train.managedFinishingScheduling && (train.routeStepIndex == route.lastStepIndex || route.steps.isEmpty) {
            // The train is already stopped but make sure to update the scheduling status
            try layout.stopCompletely(train.id)
            return .none()
        }
                
        // Setup the start route index of the train
        train.startRouteIndex = train.routeStepIndex
                
        // If the train is stopped, start it
        if train.state == .stopped {
            train.stateChangeRequest = .start
        }
        
        // Try to reserve the necessary leading blocks and, if successfull, ensure that the train is actually running
        let result = try controller.reserveLeadBlocks(route: route, currentBlock: currentBlock)
        if result {
            BTLogger.router.debug("\(train, privacy: .public): start because the leading blocks could be reserved for \(route.steps.debugDescription, privacy: .public)")
            train.stateChangeRequest = nil
            train.state = .running
            layout.setTrainSpeed(train, LayoutFactory.DefaultMaximumSpeed) { }
            return .one(.stateChanged)
        } else {
            BTLogger.router.debug("\(train, privacy: .public): could not start because the leading blocks could not be reserved for \(route.steps.debugDescription, privacy: .public)")
            train.stateChangeRequest = nil
        }

        return .none()
    }
     
}
