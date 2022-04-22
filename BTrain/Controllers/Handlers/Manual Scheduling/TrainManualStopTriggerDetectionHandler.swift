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

final class TrainManualStopTriggerDetectionHandler: TrainManualSchedulingHandler {
    
    var events: Set<TrainEvent> {
        [.feedbackTriggered]
    }
    
    func process(layout: Layout, train: Train, event: TrainEvent, controller: TrainController) throws -> TrainHandlerResult {
        guard train.state != .stopped && train.state != .stopping else {
            return .none()
        }
                
        guard let currentBlock = layout.currentBlock(train: train) else {
            return .none()
        }

        guard try layout.nextValidBlockForLocomotive(from: currentBlock, train: train) == nil else {
            return .none()
        }
        
        if train.wagonsPushedByLocomotive {
            train.runtimeInfo = "Stopped because no next block detected"
            BTLogger.warning("No next block detected, stopping \(train.name) by precaution.")
            return try controller.stop(completely: true)
        } else {
            // If there are no possible next block detected, we need to stop the train
            // when it reaches the end of the block to avoid a collision.
            if try layout.atEndOfBlock(train: train) {
                train.runtimeInfo = "Stopped because no next block detected"
                BTLogger.warning("No next block detected, stopping \(train.name) by precaution.")
                return try controller.stop(completely: true)
            }
        }

        return .none()
    }
    
}
