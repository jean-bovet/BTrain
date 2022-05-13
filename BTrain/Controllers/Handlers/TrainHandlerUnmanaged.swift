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

final class TrainHandlerUnmanaged {
        
    func process(layout: Layout, train: Train, event: TrainEvent, controller: TrainControlling) throws -> TrainHandlerResult {
        var result = TrainHandlerResult(events: [])
        if event == .feedbackTriggered {
            result = result.appending(try moveTrainInsideBlock(layout: layout, train: train, event: event, controller: controller))
            result = result.appending(try moveTrainToNextBlock(layout: layout, train: train, event: event, controller: controller))
            result = result.appending(try stopDetection(layout: layout, train: train, event: event, controller: controller))
        }
        
        if train.state == .stopped && train.speed.actualKph > 0 {
            BTLogger.router.debug("\(train, privacy: .public): train is now running")
            train.state = .running
            result = result.appending(.stateChanged)
        } else if train.state != .stopped && train.state != .stopping && train.speed.actualKph == 0 {
            BTLogger.router.debug("\(train, privacy: .public): train is now stopped")
            train.state = .stopped
            result = result.appending(.stateChanged)
        }

        return result
    }
    
    func moveTrainInsideBlock(layout: Layout, train: Train, event: TrainEvent, controller: TrainControlling) throws -> TrainHandlerResult {
        guard let currentBlock = layout.currentBlock(train: train) else {
            return .none()
        }

        guard let trainInstance = currentBlock.train else {
            return .none()
        }
        
        guard train.state != .stopped else {
            return .none()
        }
        
        let direction = trainInstance.direction
        var result: TrainHandlerResult = .none()
        
        // Iterate over all the feedbacks of the block and react to those who are triggered (aka detected)
        for (index, feedback) in currentBlock.feedbacks.enumerated() {
            guard let f = layout.feedback(for: feedback.feedbackId), f.detected else {
                continue
            }
            
            let position = layout.newPosition(forTrain: train, enabledFeedbackIndex: index, direction: direction)
            if train.position != position {
                try layout.setTrainPosition(train, position)
                
                BTLogger.router.debug("\(train, privacy: .public): moved to position \(train.position) in \(currentBlock.name, privacy: .public), direction \(direction)")
                
                result = result.appending(.movedInsideBlock)
            }
        }
        
        return result
    }

    func moveTrainToNextBlock(layout: Layout, train: Train, event: TrainEvent, controller: TrainControlling) throws -> TrainHandlerResult {
        guard train.state != .stopped else {
            return .none()
        }
                
        // Find out what is the entry feedback for the next block
        guard let entryFeedback = try layout.entryFeedback(for: train), entryFeedback.feedback.detected else {
            // The entry feedback is not yet detected, nothing more to do
            return .none()
        }
        
        guard let position = entryFeedback.block.indexOfTrain(forFeedback: entryFeedback.feedback.id, direction: entryFeedback.direction) else {
            throw LayoutError.feedbackNotFound(feedbackId: entryFeedback.feedback.id)
        }
                
        BTLogger.router.debug("\(train, privacy: .public): enters block \(entryFeedback.block, privacy: .public) at position \(position), direction \(entryFeedback.direction)")
                
        try layout.setTrainToBlock(train.id, entryFeedback.block.id, position: .custom(value: position), direction: entryFeedback.direction)
                            
        return .one(.movedToNextBlock)
    }

    func stopDetection(layout: Layout, train: Train, event: TrainEvent, controller: TrainControlling) throws -> TrainHandlerResult {
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
            BTLogger.router.warning("\(train, privacy: .public): no next block detected, stopping by precaution")
            return try controller.stop(completely: true)
        } else {
            // If there are no possible next block detected, we need to stop the train
            // when it reaches the end of the block to avoid a collision.
            if try layout.atEndOfBlock(train: train) {
                train.runtimeInfo = "Stopped because no next block detected"
                BTLogger.router.warning("\(train, privacy: .public): no next block detected, stopping by precaution")
                return try controller.stop(completely: true)
            }
        }

        return .none()
    }

}
