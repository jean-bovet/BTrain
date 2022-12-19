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

extension Double {
    /// Distance used to shift the position of the train after it was detected by a feedback to either after
    /// or before the feedback, depending on the direction of travel of the train within the block. This is to
    /// ensure there are no ambiguities when converting a distance to a position index within the block.
    /// Otherwise, if the distance is exactly on top of a feedback, we don't know which position index to
    /// pick for the train: after or before the feedback?
    private static let distanceDelta = 0.001

    /// Returns the distance right after this one
    var after: Double {
        self + Double.distanceDelta
    }

    /// Returns the distance right before this one
    var before: Double {
        self - Double.distanceDelta
    }
}

struct FeedbackPosition {
    let blockId: Identifier<Block>
    let index: Int
    let distance: Double

    func trainPosition(direction: Direction) -> TrainPosition {
        switch direction {
        case .previous:
            return TrainPosition(blockId: blockId, index: index, distance: distance.before)

        case .next:
            return TrainPosition(blockId: blockId, index: index + 1, distance: distance.after)
        }
    }
}
