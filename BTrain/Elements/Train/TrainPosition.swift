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

/// Defines a single train position.
///
/// - A train can have multiple positions, such as the head and tail of the train.
/// - Each position can be located in a different block if the train is moving between blocks.
/// - Each position contains enough information to be sufficient to spread out the train in the layout. That includes: the block, the feedback index and the direction of travel.
struct TrainPosition: Equatable, Codable, CustomStringConvertible {
    enum TrainPositionError: Error {
        case occupiedBlockNotFound(blockId: Identifier<Block>)
    }

    /// The block in which this position is located
    var blockId: Identifier<Block>

    /// The index of the position within the block.
    /// Note: the index is increasing in the natural direction of the block (.next)
    var index: Int

    /// Distance, in cm, from the beginning of the block in the direction of travel of the train
    var distance: Double

    /// Direction of travel of the train
    var direction: Direction

    var description: String {
        description(nil)
    }

    mutating func toggleDirection() {
        direction = direction.opposite
    }

    /// When comparing to position, the distance is only compared up to a thousandth because with
    /// double operations, there will be rounding errors.
    /// - Parameters:
    ///   - lhs: The left-hand side position
    ///   - rhs: The right-hand side position
    /// - Returns: true if both positions are equal
    static func == (lhs: TrainPosition, rhs: TrainPosition) -> Bool {
        let delta = fabs(lhs.distance.distance(to: rhs.distance))
        return lhs.blockId == rhs.blockId
            && lhs.index == rhs.index
            && delta < 0.0001
    }

    func description(_ layout: Layout?) -> String {
        if let block = layout?.blocks[blockId] {
            return "\(block.name):\(index):\(String(format: "%.3f", distance)):\(direction)"
        } else {
            return "\(blockId.uuid):\(index):\(String(format: "%.3f", distance)):\(direction)"
        }
    }
}
