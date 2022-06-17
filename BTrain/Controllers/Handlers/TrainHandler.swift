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
import OrderedCollections

/// The event available to the handlers
enum TrainEvent: Hashable, CustomStringConvertible {
    /// A feedback sensor has been triggered
    case feedbackTriggered(Feedback)
    
    /// The scheduling state of the train has changed. This happens in the following scenarios:
    /// - When a train starts for the first time
    /// - When a train stops
    /// - When a train finishes a route
    case schedulingChanged(train: Train)
        
    /// A train restart timer has expired, meaning that the train associated with this timer
    /// should restart again.
    case restartTimerExpired(train: Train)
    
    /// A turnout state changed
    case turnoutChanged(Turnout)
    
    /// A train direction has changed
    case directionChanged
    
    /// A train speed has changed
    case speedChanged(Train, TrainSpeed.UnitKph)
    
    /// A train state has changed.
    case stateChanged

    /// A train reserved blocks (occupied or leading) have changed
    case reservedBlocksChanged
    
    /// A train has moved inside a block.
    case movedInsideBlock(Train)
    
    /// A train has moved to the next block
    case movedToNextBlock(Train)
    
    var description: String {
        switch self {
        case .feedbackTriggered:
            return "Feedback Triggered"
        case .schedulingChanged:
            return "Scheduling Changed"
        case .restartTimerExpired(let train):
            return "Restart Timer Expired for \(train)"
        case .turnoutChanged:
            return "Turnout Changed"
        case .directionChanged:
            return "Direction Changed"
        case .speedChanged:
            return "Speed Changed"
        case .stateChanged:
            return "State Changed"
        case .movedInsideBlock:
            return "Move Inside Block"
        case .movedToNextBlock:
            return "Move to Next Block"
        case .reservedBlocksChanged:
            return "Reserved Blocks Changed"
        }
    }
}

/// Structure that describes the result of a handler's processing.
final class TrainHandlerResult {
    
    /// The array of events that needs follow-up processing.
    ///
    /// For example, a feedback triggers several handlers that, in turn,
    /// trigger other events, such as ``TrainEvent/movedInsideBlock``.
    var events = OrderedSet<TrainEvent>()

    func append(_ event: TrainEvent) {
        events.append(event)
    }

    func append(_ result: TrainHandlerResult) {
        events.append(contentsOf: result.events)
    }

    /// Returns a result that does not require any follow up events
    /// - Returns: the result
    static func none() -> TrainHandlerResult {
        .init()
    }

}
