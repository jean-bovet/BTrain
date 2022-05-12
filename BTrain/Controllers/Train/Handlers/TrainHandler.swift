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

/// The event available to the handlers
enum TrainEvent: Hashable, CustomStringConvertible {
    /// A feedback sensor has been triggered
    case feedbackTriggered
    
    /// The scheduling state of the train has changed. This happens in the following scenarios:
    /// - When a train starts for the first time
    /// - When a train stops
    /// - When a train finishes a route
    case schedulingChanged
        
    /// A train restart timer has expired, meaning that the train associated with this timer
    /// should restart again.
    case restartTimerExpired(train: Train)
    
    /// A turnout state changed
    case turnoutChanged
    
    /// A train direction has changed
    case directionChanged
    
    /// A train speed has changed
    case speedChanged
    
    /// A train state has changed.
    case stateChanged
    
    /// A train has moved inside a block.
    case movedInsideBlock
    
    /// A train has moved to the next block
    case movedToNextBlock
    
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
        }
    }
}

/// Structure that describes the result of a handler's processing.
struct TrainHandlerResult {
    
    /// The array of events that needs follow-up processing.
    ///
    /// For example, a feedback triggers several handlers that, in turn,
    /// trigger other events, such as ``TrainEvent/movedInsideBlock``.
    let events: [TrainEvent]
    
    /// Returns a result that does not require any follow up events
    /// - Returns: the result
    static func none() -> TrainHandlerResult {
        .init(events: [])
    }
    
    /// Returns a result that contains a single event
    /// - Parameter event: the event that requires further processing
    /// - Returns: the result
    static func one(_ event: TrainEvent) -> TrainHandlerResult {
        .init(events: [event])
    }
    
    /// Returns a new result by appending the events of this result and the `event` parameter.
    /// - Parameter event: the event to append
    /// - Returns: a new result with the event appended
    func appending(_ event: TrainEvent) -> TrainHandlerResult {
        .init(events: self.events + [event])
    }
    
    /// Returns a new result by appending the events of this result and the `result` parameter.
    /// - Parameter result: the result whose events need to be appended
    /// - Returns: a new result with the events appended
    func appending(_ result: TrainHandlerResult) -> TrainHandlerResult {
        .init(events: self.events + result.events)
    }
}

/// Protocol defining some common controlling functions that handlers can use
protocol TrainControlling {
    
    /// Request to restart the train after a specific amount of time specified by the route and block.
    /// - Parameter train: the train to restart after some amount of time
    func scheduleRestartTimer(train: Train)
    
    /// Stop the train by setting its speed to 0.
    ///
    /// - Parameter completely: true if the train stops completely, false otherwise. A train that stops completely will have its ``Train/scheduling`` changed to ``Train/Schedule/manual``.
    /// - Returns: the result
    func stop(completely: Bool) throws -> TrainHandlerResult
    
}

/// Defines a protocol for a handler that gets invoked during the automatic scheduling of a train (when the train is automatically managed by BTrain).
protocol TrainAutomaticSchedulingHandler {
    
    /// This method is invoked when an event machings ``TrainAutomaticSchedulingHandler/events`` is triggered.
    ///
    /// - Parameters:
    ///   - layout: the layout
    ///   - train: the train
    ///   - route: the route
    ///   - event: the event that triggered this method invocation
    ///   - controller: the train controller
    /// - Returns: returns the result of the process, which can include one or more follow up events
    func process(layout: Layout, train: Train, route: Route, event: TrainEvent, controller: TrainControlling) throws -> TrainHandlerResult

}

/// Defines a protocol for a handler that gets invoked during the manual scheduling of a train (when the train
/// is manually operated by the user).
protocol TrainManualSchedulingHandler {
    
    /// The set of events this handler is interested in getting notified about
    var events: Set<TrainEvent> { get }
    
    /// This method is invoked when an event machings ``TrainManualSchedulingHandler/events`` is triggered.
    ///
    /// - Parameters:
    ///   - layout: the layout
    ///   - train: the train
    ///   - event: the event that triggered this method invocation
    ///   - controller: the train controller
    /// - Returns: returns the result of the process, which can include one or more follow up events
    func process(layout: Layout, train: Train, event: TrainEvent, controller: TrainControlling) throws -> TrainHandlerResult

}
