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

/// The position of a train includes the block in which that position is located, the index of the position (relative to the natural direction of the block
/// and the feedbacks inside the block) and finally the direction of travel of the train within the block.
///
/// Note: the direction of travel of the train is used to determine if a position is before (or after) another position in the same block.
struct TrainPosition: Equatable, Codable, CustomStringConvertible {
    
    enum TrainPositionError: Error {
        case occupiedBlockNotFound(blockId: Identifier<Block>)
    }
    
    /// The index of the block in which that position is located.
    /// Note: the index is increasing in the direction of travel of the train
    var blockId: Identifier<Block>
    
    /// The index of the position within the block.
    /// Note: the index is increasing in the natural direction of the block (.next)
    var index: Int
    
    /// Distance, in cm, from the beginning of the block in the direction of travel of the train
    var distance: Double
    
    var description: String {
        "\(blockId.uuid):\(index):\(distance)"
    }
    
    /// When comparing to position, the distance is only compared up to a thousandth because with
    /// double operations, there will be rouding errors.
    /// - Parameters:
    ///   - lhs: The left-hand side position
    ///   - rhs: The right-hand side position
    /// - Returns: true if both positions are equal
    static func ==(lhs: TrainPosition, rhs: TrainPosition) -> Bool {
        let delta = fabs(lhs.distance.distance(to: rhs.distance))
        return lhs.blockId == rhs.blockId
        && lhs.index == rhs.index
        && delta < 0.0001
    }

}
