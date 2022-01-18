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
        entryFeedbackNext = defaultEntryFeedback(for: .next)
        brakeFeedbackNext = defaultBrakeFeedback(for: .next)
        stopFeedbackNext = defaultStopFeedback(for: .next)
        
        entryFeedbackPrevious = defaultEntryFeedback(for: .previous)
        brakeFeedbackPrevious = defaultBrakeFeedback(for: .previous)
        stopFeedbackPrevious = defaultStopFeedback(for: .previous)
    }

    func defaultEntryFeedback(for direction: Direction) -> Identifier<Feedback>? {
        switch(direction) {
        case .next:
            return feedbacks.first?.feedbackId
        case .previous:
            return feedbacks.last?.feedbackId
        }
    }
    
    // [ f1 ]
    // [ f1 f2 ]
    // [ f1 f2 f3 ]
    func defaultBrakeFeedback(for direction: Direction) -> Identifier<Feedback>? {
        let defaultBrakeFeedbackIndex: Int
        if feedbacks.count == 2 {
            defaultBrakeFeedbackIndex = 0
        } else if feedbacks.count > 2 {
            defaultBrakeFeedbackIndex = 1
        } else {
            defaultBrakeFeedbackIndex = 0
        }
        
        switch(direction) {
        case .next:
            return feedbacks.element(at: defaultBrakeFeedbackIndex)?.feedbackId ?? defaultEntryFeedback(for: .next)
        case .previous:
            return feedbacks.element(fromEndAt: defaultBrakeFeedbackIndex)?.feedbackId ?? defaultEntryFeedback(for: .previous)
        }
    }

    func defaultStopFeedback(for direction: Direction) -> Identifier<Feedback>? {
        switch(direction) {
        case .next:
            return feedbacks.last?.feedbackId ?? defaultBrakeFeedback(for: .next)
        case .previous:
            return feedbacks.first?.feedbackId ?? defaultBrakeFeedback(for: .previous)
        }
    }

    func entryFeedback(for direction: Direction) -> Identifier<Feedback>? {
        switch(direction) {
        case .next:
            return entryFeedbackNext ?? defaultEntryFeedback(for: .next)
        case .previous:
            return entryFeedbackPrevious ?? defaultEntryFeedback(for: .previous)
        }
    }

    func brakeFeedback(for direction: Direction) -> Identifier<Feedback>? {
        switch(direction) {
        case .next:
            return brakeFeedbackNext ?? defaultBrakeFeedback(for: .next)
        case .previous:
            return brakeFeedbackPrevious ?? defaultBrakeFeedback(for: .previous)
        }
    }

    func stopFeedback(for direction: Direction) -> Identifier<Feedback>? {
        switch(direction) {
        case .next:
            return stopFeedbackNext ?? defaultStopFeedback(for: .next)
        case .previous:
            return stopFeedbackPrevious ?? defaultStopFeedback(for: .previous)
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
