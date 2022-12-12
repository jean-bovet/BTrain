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
                                         
/// The train positions: a front position and a back position.
///
/// Notes:
/// - Each of these positions correspond to a magnet that triggers a feedback in the layout.
/// - A train that only moves forward needs only one magnet at the front of the train.
/// - A train that moves forward and backward needs a magnet at the front and the back of the train
struct TrainPositions: Equatable, Codable {
    
    /// The position at the head of the train (where the locomotive is located)
    var head: TrainPosition?
    
    /// The position at the tail of the train (where the last car is located)
    var tail: TrainPosition?
    
    func description(_ layout: Layout) -> String {
        if let head = head, let tail = tail {
            return "􀼯\(tail.description(layout))-\(head.description(layout))􀼮"
        } else if let head = head {
            return "􀼯?-\(head.description(layout))􀼮"
        } else if let tail = tail {
            return "􀼯\(tail.description(layout))-?􀼮"
        } else {
            return "􀼯?-?􀼮"
        }
    }
    
    static func head(blockId: Identifier<Block>, index: Int, distance: Double) -> TrainPositions {
        TrainPositions(head: .init(blockId: blockId, index: index, distance: distance), tail: nil)
    }

    static func tail(blockId: Identifier<Block>, index: Int, distance: Double) -> TrainPositions {
        TrainPositions(head: nil, tail: .init(blockId: blockId, index: index, distance: distance))
    }

    static func both(blockId: Identifier<Block>, headIndex: Int, headDistance: Double, tailIndex: Int, tailDistance: Double) -> TrainPositions {
        TrainPositions(head: .init(blockId: blockId, index: headIndex, distance: headDistance),
                       tail: .init(blockId: blockId, index: tailIndex, distance: tailDistance))
    }

}
