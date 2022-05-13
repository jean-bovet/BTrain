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

/// This classes manages to stop a train inside a block when a stop trigger is detected.
final class TrainExecuteStopInBlockHandler: TrainAutomaticSchedulingHandler {
    
    var events: Set<TrainEvent> {
        [
            // When a stop is requested, this handler must be invoked
            .stopRequested,
            
            // When a feedback is triggered, this handler must be invoked
            .feedbackTriggered
        ]
    }

    func process(layout: Layout, train: Train, route: Route, event: TrainEvent, controller: TrainControlling) throws -> TrainHandlerResult {
        guard train.state != .stopped && train.state != .stopping else {
            return .none()
        }
                
        guard let currentBlock = layout.currentBlock(train: train) else {
            return .none()
        }

        guard let trainInstance = currentBlock.train else {
            return .none()
        }
        
        guard let stateChangeRequest = train.stateChangeRequest else {
            return .none()
        }
        
        let direction = trainInstance.direction
        var result: TrainHandlerResult = .none()
        for feedback in currentBlock.feedbacks {
            guard let f = layout.feedback(for: feedback.feedbackId), f.detected else {
                continue
            }
            
            if train.state == .running {
                guard let brakeFeedback = currentBlock.brakeFeedback(for: direction) else {
                    throw LayoutError.brakeFeedbackNotFound(block: currentBlock)
                }
                if brakeFeedback == f.id {
                    BTLogger.router.debug("\(train, privacy: .public): braking in \(currentBlock.name, privacy: .public) at position \(train.position), direction \(direction)")
                    train.state = .braking
                    layout.setTrainSpeed(train, currentBlock.brakingSpeed ?? LayoutFactory.DefaultBrakingSpeed) {}
                    result = .one(.stateChanged)
                }
            }
            
            if train.state == .braking {
                guard let stopFeedback = currentBlock.stopFeedback(for: direction) else {
                    throw LayoutError.stopFeedbackNotFound(block: currentBlock)
                }
                if stopFeedback == f.id {
                    BTLogger.router.debug("\(train, privacy: .public): stopping in \(currentBlock.name, privacy: .public) at position \(train.position), direction \(direction)")
                    result = try controller.stop(completely: stateChangeRequest == .stopCompletely)
                    
                    // Reschedule if necessary
                    if case let .stopAndRestart(delay) = stateChangeRequest, delay > 0 {
                        BTLogger.router.debug("\(train, privacy: .public): schedule timer to restart train in \(delay, format: .fixed(precision: 1)) seconds")
                        
                        // The layout controller is going to schedule the appropriate timer given the `restartDelayTime` value
                        train.timeUntilAutomaticRestart = delay
                        controller.scheduleRestartTimer(train: train)
                    }
                }
            }
        }
        return result
    }
    
}
