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

struct LayoutEventStateMachine {
    /// Handles a layout event and returning an optional train event.
    ///
    /// The rules applied are:
    /// 1. Feedback triggered leads to an update of the train's position
    /// 2. Speed change leads to an update of the train's speed
    /// 3. Turnout changed leads to an update of the reserved blocks settled length
    ///
    /// - Parameters:
    ///   - layoutEvent: The layout event
    ///   - train: the train to process
    /// - Returns: an optional train event
    func handle(layoutEvent: StateMachine.LayoutEvent, train: TrainControlling) throws -> StateMachine.TrainEvent? {
        switch layoutEvent {
        case let .feedback(feedback):
            if train.state != .stopped {
                if try train.updatePosition(with: feedback) {
                    return .position(train)
                }
            }

        case let .speed(eventTrain, speed):
            if eventTrain.id == train.id {
                train.speed = speed
                return .speed(train)
            }

        case let .turnout(turnout):
            if train.updateReservedBlocksSettledLength(with: turnout) {
                return .reservedBlocksSettledLengthChanged(train)
            }

        case let .direction(eventTrain):
            if eventTrain.id == train.id {
                if try train.updateReservedBlocks() {
                    return .reservedBlocksChanged(train)
                }
            }
        }

        return nil
    }
}
