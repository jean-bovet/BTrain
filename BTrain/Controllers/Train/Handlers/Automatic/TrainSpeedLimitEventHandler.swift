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

/// This class manages the speed limit in automatic scheduling. For example, when a train enters a new block or moves
/// within a block, the speed might need to be adjusted given the reserved elements in front of the train: blocks or turnouts can
/// have speed limitation that needs to be honored.
final class TrainSpeedLimitEventHandler: TrainAutomaticSchedulingHandler {
    
    var events: Set<TrainEvent> {
        [.movedToNextBlock, .movedInsideBlock]
    }
    
    func process(layout: Layout, train: Train, route: Route, event: TrainEvent, controller: TrainControlling) throws -> TrainHandlerResult {
        layout.adjustSpeedLimit(train)
        return .none()
    }    
}
