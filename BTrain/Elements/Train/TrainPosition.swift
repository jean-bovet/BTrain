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
            
    var description: String {
        "\(blockId.uuid):\(index)"
    }

    func isAfterOrEqual(_ other: TrainPosition, reservation: Train.Reservation) throws -> Bool {
        if self == other {
            return true
        } else {
            return try isAfter(other, reservation: reservation)
        }
    }
    
    /// Returns true if the location is after ``other``, in the direction of travel of the train.
    /// - Parameters:
    ///   - other: the other location
    ///   - reservation: the reservation of the train
    /// - Returns: true if this position is after ``other``, false otherwise
    func isAfter(_ other: TrainPosition, reservation: Train.Reservation) throws -> Bool {
        guard let blockIndex = reservation.blockIndex(for: blockId) else {
            throw TrainPositionError.occupiedBlockNotFound(blockId: blockId)
        }
        guard let otherBlockIndex = reservation.blockIndex(for: other.blockId) else {
            throw TrainPositionError.occupiedBlockNotFound(blockId: other.blockId)
        }

        if blockIndex > otherBlockIndex {
            return false
        } else if blockIndex < otherBlockIndex {
            return true
        } else {
            // Same block. Now the direction matters to compare
            guard let direction = try reservation.directionInBlock(for: blockId) else {
                throw LayoutError.directionNotFound(blockId: blockId)
            }
            if direction == .next {
                return index > other.index
            } else {
                return index < other.index
            }
        }
    }

    func isBeforeOrEqual(_ other: TrainPosition, reservation: Train.Reservation) throws -> Bool {
        if self == other {
            return true
        } else {
            return try isBefore(other, reservation: reservation)
        }
    }
    
    func isBefore(_ other: TrainPosition, reservation: Train.Reservation) throws -> Bool {
        if self == other {
            return false
        } else {
            return try !isAfter(other, reservation: reservation)
        }
    }
    
}

extension Train.Reservation {
    
    // TODO: documentation
    func blockIndex(for blockId: Identifier<Block>) -> Int? {
        if let blockIndex = occupied.blocks.firstIndex(where: {$0.id == blockId}) {
            return blockIndex
        }
        if let blockIndex = leading.blocks.firstIndex(where: {$0.id == blockId}) {
            return -1-blockIndex
        }
        if let nextBlock = nextBlock, nextBlock.id == blockId {
            return -1
        }
        return nil
    }

    func directionInBlock(for blockId: Identifier<Block>) throws -> Direction? {
        if let block = occupied.blocks.first(where: {$0.id == blockId}) {
            if let ti = block.trainInstance {
                return ti.direction
            } else {
                throw LayoutError.trainNotFoundInBlock(blockId: blockId)
            }
        }
        return nil
    }
}

