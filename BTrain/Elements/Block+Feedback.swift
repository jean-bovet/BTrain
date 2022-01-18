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

extension Block {
    
    func assign(_ feedbackIds: [Identifier<Feedback>]) {
        feedbacks = feedbackIds.map { BlockFeedback(id: UUID().uuidString, feedbackId: $0) }
    }
    
    func remove(_ feedback: BlockFeedback) {
        feedbacks.removeAll(where: { $0.id == feedback.id })
    }
    
    func add(_ feedbackId: Identifier<Feedback>) {
        feedbacks.append(BlockFeedback(id: UUID().uuidString, feedbackId: feedbackId))
    }
    
    func remove(feedbackId: Identifier<Feedback>) {
        feedbacks.removeAll(where: { $0.feedbackId == feedbackId })
    }
    
    func autoFillFeedbacks() {
        entryFeedbackNext = feedbacks.first?.feedbackId
        brakeFeedbackNext = feedbacks.element(at: 1)?.feedbackId ?? entryFeedbackNext
        stopFeedbackNext = feedbacks.element(at: 2)?.feedbackId ?? brakeFeedbackNext
        
        entryFeedbackPrevious = stopFeedbackNext
        brakeFeedbackPrevious = brakeFeedbackNext
        stopFeedbackPrevious = entryFeedbackNext
    }
    
    func entryFeedback(for direction: Direction) -> Identifier<Feedback>? {
        switch(direction) {
        case .previous:
            return entryFeedbackPrevious ?? feedbacks.last?.feedbackId
        case .next:
            return entryFeedbackNext ?? feedbacks.first?.feedbackId
        }
    }
    
    func indexOfTrain(forFeedback: Identifier<Feedback>, direction: Direction) -> Int? {
        guard let index = feedbacks.firstIndex(where: { $0.feedbackId == forFeedback }) else {
            return nil
        }
        switch(direction) {
        case .next:
            return index + 1
        case .previous:
            return index
        }
    }
    
}
