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

final class TrainStartHandler: TrainAutomaticRouteHandling {
    
    var events: Set<TrainEvent> {
        [.schedulingChanged, .stateChanged, .movedToNextBlock,
         // A train can stop in a block because no blocks can be reserved ahead.
         // But when it finally moves to the last part of the block, the block
         // ahead can be reserved (ie the tail of the train frees a turnout),
         // we want to make sure to restart it.
         .movedInsideBlock]
    }

    func process(layout: Layout, train: Train, route: Route, event: TrainEvent, controller: TrainController) throws -> TrainController.Result {
        // Note: we also want to start a train that is braking to stop temporarily, which can happen
        // when the next block that was occupied (and caused the train to brake in the first place) becomes free.
        guard train.state == .stopped || (train.state == .braking && train.stopTrigger?.isTemporary == true) else {
            return .none()
        }

        guard let currentBlock = layout.currentBlock(train: train) else {
            return .none()
        }

        // Do not start the train if there is still time for the train until it has to restart
        guard train.timeUntilAutomaticRestart == 0 else {
            return .none()
        }
        
        // If the train was scheduled to finish, make sure it is finished but only
        // if it has reached the last block of the route (otherwise, a train can
        // be stopped in the middle of the route if that route was blocked for some reason).
        if train.automaticFinishingScheduling && train.routeStepIndex == route.lastStepIndex {
            // The train is already stopped but make sure to update the scheduling status
            try layout.stopCompletely(train.id)
            return .none()
        }
                
        // Setup the start route index of the train
        train.startRouteIndex = train.routeStepIndex
        
        // And try to reserve the necessary leading blocks
        let result = try controller.reserveLeadBlocks(route: route, currentBlock: currentBlock, trainStarting: true)
        if result {
            BTLogger.debug("Start train \(train.name) because the next blocks could be reserved (route: \(route.steps.debugDescription))")
            train.stopTrigger = nil
            train.state = .running
            layout.setTrainSpeed(train, LayoutFactory.DefaultMaximumSpeed) { }
            return .one(.stateChanged)
        }

        return .none()
    }
     
}
