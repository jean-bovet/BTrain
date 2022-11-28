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

extension TrainPosition {
    
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
