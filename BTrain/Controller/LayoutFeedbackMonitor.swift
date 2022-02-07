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

// This class monitors all the layout feedback and optionally detects
// any unexpected feedbacks in order to stop all the trains to avoid collisions.
final class LayoutFeedbackMonitor {
    
    let layout: Layout
    
    var expectedFeedbacks = Set<Identifier<Feedback>>()
    
    init(layout: Layout) {
        self.layout = layout
    }
    
    // Update the set of expected feedbacks for the specified trains
    func update(with trains: [Train]) throws {
        expectedFeedbacks.removeAll()

        for train in trains {
            try updateExpectedFeedbacks(train: train)
        }
    }
    
    private func updateExpectedFeedbacks(train: Train) throws {
        guard let currentBlock = layout.currentBlock(train: train) else {
            return
        }

        for feedback in currentBlock.feedbacks {
            expectedFeedbacks.insert(feedback.feedbackId)
        }
        
        if train.manualScheduling {
            guard let nextBlock = layout.nextBlockForLocomotive(from: currentBlock, train: train) else {
                return
            }

            let (entryFeedback, _) = try layout.entryFeedback(from: currentBlock, to: nextBlock)
            if let entryFeedback = entryFeedback {
                expectedFeedbacks.insert(entryFeedback.id)
            }
        } else {
            guard let nextBlock = layout.nextBlock(train: train) else {
                return
            }

            guard try layout.shouldHandleTrainMoveToNextBlock(train: train) else {
                return
            }
            
            let (entryFeedback, _) = try layout.entryFeedback(from: currentBlock, to: nextBlock)
            if let entryFeedback = entryFeedback {
                expectedFeedbacks.insert(entryFeedback.id)
            }
        }
    }
    
    // Detect any unexpected feedback and throw an exception if that is the case.
    // It is up to the caller to handle that exception in the appropriate manner.
    func handleUnexpectedFeedbacks() throws {
        for feedback in layout.feedbacks.filter({ $0.detected }) {
            if !expectedFeedbacks.contains(feedback.id) {
                BTLogger.error("Unexpected feedback \(feedback.name) detected!")
                throw LayoutError.unexpectedFeedback(feedback: feedback)
            }
        }
    }
    
}
