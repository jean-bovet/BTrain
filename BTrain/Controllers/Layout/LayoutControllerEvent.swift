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
enum LayoutControllerEvent: CustomStringConvertible {
    /// A feedback sensor has been triggered
    case feedbackTriggered(Feedback)
    
    /// The scheduling state of the train has changed.
    ///
    /// This happens in the following scenarios:
    /// - When a train starts for the first time
    /// - When a train stops
    /// - When a train finishes a route
    case schedulingChanged(Train)
        
    /// A train restart timer has expired, meaning that the train associated with this timer
    /// should restart again.
    case restartTimerExpired(Train)
    
    /// A turnout state changed
    case turnoutChanged(Turnout)
    
    /// A train direction has changed
    case directionChanged(Train)
    
    /// A train speed has changed
    case speedChanged(Train, SpeedKph)

    /// The position of a train changed because the user either removed or added manually a train to the layout
    case trainPositionChanged(Train)

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
        case .trainPositionChanged(let train):
            return "Train removed: \(train)"
        }
    }
}
