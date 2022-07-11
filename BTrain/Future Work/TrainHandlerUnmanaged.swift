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

// TODO: re-use some logic in this class when we introduce the semi-automatic mode
final class TrainHandlerUnmanaged {
        
    let layout: Layout
    let executor: LayoutController
    let train: Train
    let event: TrainEvent
    var resultingEvents = TrainHandlerResult()

    static func process(layout: Layout, executor: LayoutController, train: Train, event: TrainEvent) throws -> TrainHandlerResult {
        let handler = TrainHandlerUnmanaged(layout: layout, executor: executor, train: train, event: event)
        return try handler.process()
    }
    
    private init(layout: Layout, executor: LayoutController, train: Train, event: TrainEvent) {
        self.layout = layout
        self.executor = executor
        self.train = train
        self.event = event
    }
    
    private func process() throws -> TrainHandlerResult {
        if case .feedbackTriggered(_) = event {
            try moveTrainInsideBlock()
            try moveTrainToNextBlock()
            try stopDetection()
        }
        
        if train.state == .stopped && train.speed.actualKph > 0 {
            BTLogger.router.debug("\(self.train, privacy: .public): train is now running")
            train.state = .running
            resultingEvents.append(.stateChanged)
        } else if train.state != .stopped && train.speed.actualKph == 0 {
            BTLogger.router.debug("\(self.train, privacy: .public): train is now stopped")
            train.state = .stopped
            resultingEvents.append(.stateChanged)
        }

        return resultingEvents
    }
    
    func moveTrainInsideBlock() throws {
        guard let currentBlock = layout.currentBlock(train: train) else {
            return
        }

        guard let trainInstance = currentBlock.train else {
            return
        }
        
        guard train.state != .stopped else {
            return
        }
        
        let direction = trainInstance.direction
        
        // Iterate over all the feedbacks of the block and react to those who are triggered (aka detected)
        for (index, feedback) in currentBlock.feedbacks.enumerated() {
            guard let f = layout.feedback(for: feedback.feedbackId), f.detected else {
                continue
            }
            
            let position = layout.newPosition(forTrain: train, enabledFeedbackIndex: index, direction: direction)
            if train.position != position {
                try executor.setTrainPosition(train, position, removeLeadingBlocks: true)
                
                BTLogger.router.debug("\(self.train, privacy: .public): moved to position \(self.train.position) in \(currentBlock.name, privacy: .public), direction \(direction)")
                
                resultingEvents.append(.movedInsideBlock(train))
            }
        }
    }

    func moveTrainToNextBlock() throws {
        guard train.state != .stopped else {
            return
        }
                
        // Find out what is the entry feedback for the next block
        guard let entryFeedback = try layout.entryFeedback(for: train), entryFeedback.feedback.detected else {
            // The entry feedback is not yet detected, nothing more to do
            return
        }
        
        guard let position = entryFeedback.block.indexOfTrain(forFeedback: entryFeedback.feedback.id, direction: entryFeedback.direction) else {
            throw LayoutError.feedbackNotFound(feedbackId: entryFeedback.feedback.id)
        }
                
        BTLogger.router.debug("\(self.train, privacy: .public): enters block \(entryFeedback.block, privacy: .public) at position \(position), direction \(entryFeedback.direction)")
                
        try executor.setTrainToBlock(train, entryFeedback.block.id, position: .custom(value: position), direction: entryFeedback.direction, routeIndex: nil, removeLeadingBlocks: true)
                            
        resultingEvents.append(.movedToNextBlock(train))
    }

    func stopDetection() throws {
        guard train.state == .running else {
            return
        }
                
        guard let currentBlock = layout.currentBlock(train: train) else {
            return
        }

        guard try layout.nextValidBlockForLocomotive(from: currentBlock, train: train) == nil else {
            return
        }
        
        if train.wagonsPushedByLocomotive {
            train.runtimeInfo = "Stopped because no next block detected"
            BTLogger.router.warning("\(self.train, privacy: .public): no next block detected, stopping by precaution")
            executor.setTrainSpeed(train, 0)
            train.state = .stopping
            resultingEvents.append(.stateChanged)
        } else {
            // If there are no possible next block detected, we need to stop the train
            // when it reaches the end of the block to avoid a collision.
            if try layout.atEndOfBlock(train: train) {
                train.runtimeInfo = "Stopped because no next block detected"
                BTLogger.router.warning("\(self.train, privacy: .public): no next block detected, stopping by precaution")
                executor.setTrainSpeed(train, 0)
                train.state = .stopping
                resultingEvents.append(.stateChanged)
            }
        }
    }

}
