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

import XCTest

@testable import BTrain

final class TrainPositionsTests: XCTestCase {

    // MARK: - Train Forward -

    // TODO: also test when a train spans more than one block (occupied.blocks.count > 1)
    func testMoveForwardSameBlock() throws {
        var location = TrainLocation()
        
        // Block (􁉆): [ p0 f0 p1 f1 p2 f2 p3 ]
        // Train (􀼯􀼮):           ??
        assertLocation(location, back: nil, front: nil)

        let reservation = Train.Reservation()
        let block = Block()
        reservation.occupied.append(block)
        
        // Block (􁉆): [ p0 |f0| p1 f1 p2 f2 p3 ]
        // Train (􀼯􀼮):        bf
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (block.id, 0, .next),
                                      back: (block.id, 1, .next),
                                      front: (block.id, 1, .next),
                                      reservation: reservation)

        // Block (􁉆): [ p0 f0 p1 |f1| p2 f2 p3 ]
        // Train (􀼯􀼮):              bf
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (block.id, 1, .next),
                                      back: (block.id, 2, .next),
                                      front: (block.id, 2, .next),
                                      reservation: reservation)

        // Block (􁉆): [ p0 |f0| p1 f1 p2 f2 p3 ]
        // Train (􀼯􀼮):        b     f
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (block.id, 0, .next),
                                      back: (block.id, 1, .next),
                                      front: (block.id, 2, .next),
                                      reservation: reservation)

        // Block (􁉆): [ p0 f0 p1 f1 p2 |f2| p3 ]
        // Train (􀼯􀼮):      b             f
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (block.id, 2, .next),
                                      back: (block.id, 1, .next),
                                      front: (block.id, 3,.next),
                                      reservation: reservation)
    }

    
    func testMoveForwardSameBlockPrevious() throws {
        var location = TrainLocation()
        
        // Block (􁉈): [ p3 f2 p2 f1 p1 f0 p0 ]
        // Train (􀼯􀼮):           ??
        assertLocation(location, back: nil, front: nil)

        let reservation = Train.Reservation()
        let block = Block()
        reservation.occupied.append(block)

        // Block (􁉈): [ p3 |f2| p2 f1 p1 f0 p0 ]
        // Train (􀼯􀼮):        bf
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (block.id, 2, .previous),
                                      back: (block.id, 2, .previous),
                                      front: (block.id, 2, .previous),
                                      reservation: reservation)

        // Block (􁉈): [ p3 f2 p2 |f1| p1 f0 p0 ]
        // Train (􀼯􀼮):              bf
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (block.id, 1, .previous),
                                      back: (block.id, 1, .previous),
                                      front: (block.id, 1, .previous),
                                      reservation: reservation)

        // Block (􁉈): [ p3 |f2| p2 f1 p1 f0 p0 ]
        // Train (􀼯􀼮):        b     f
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (block.id, 2, .previous),
                                      back: (block.id, 2, .previous),
                                      front: (block.id, 1, .previous),
                                      reservation: reservation)

        // Block (􁉈): [ p3 f2 p2 f1 p1 |f0| p0 ]
        // Train (􀼯􀼮):      b             f
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (block.id, 0, .previous),
                                      back: (block.id, 2, .previous),
                                      front: (block.id, 0, .previous),
                                      reservation: reservation)
    }

    func testMoveForwardNextBlock() throws {
        var location = TrainLocation()
        assertLocation(location, back: nil, front: nil)

        let reservation = Train.Reservation()
        let block = Block()
        reservation.occupied.append(block)
        let nextBlock = Block()
        reservation.leading.append(nextBlock)

        location = try assertFeedback(forward: true, location: location,
                                      feedback: (block.id, 1, .next),
                                      back: (block.id, 2, .next),
                                      front: (block.id, 2, .next),
                                      reservation: reservation)
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (block.id, 2, .next),
                                      back: (block.id, 3, .next),
                                      front: (block.id, 3, .next),
                                      reservation: reservation)
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (block.id, 1, .next),
                                      back: (block.id, 2, .next),
                                      front: (block.id, 3, .next),
                                      reservation: reservation)
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (block.id, 3, .next),
                                      back: (block.id, 2, .next),
                                      front: (block.id, 4, .next),
                                      reservation: reservation)

        // Next block feedback is triggered
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (nextBlock.id, 0, .next),
                                      back: (block.id, 2, .next),
                                      front: (nextBlock.id, 1, .next),
                                      reservation: reservation)
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (nextBlock.id, 0, .next),
                                      back: (nextBlock.id, 1, .next),
                                      front: (nextBlock.id, 1, .next),
                                      reservation: reservation)
    }
    
    func testMoveForwardNextBlockPreviousDirection() throws {
        var location = TrainLocation()
        assertLocation(location, back: nil, front: nil)

        let reservation = Train.Reservation()
        let block = Block()
        reservation.occupied.append(block)
        let nextBlock = Block()
        reservation.leading.append(nextBlock)

        location = try assertFeedback(forward: true, location: location,
                                      feedback: (block.id, 1, .next),
                                      back: (block.id, 2, .next),
                                      front: (block.id, 2, .next),
                                      reservation: reservation)
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (block.id, 2, .next),
                                      back: (block.id, 3, .next),
                                      front: (block.id, 3, .next),
                                      reservation: reservation)
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (block.id, 1, .next),
                                      back: (block.id, 2, .next),
                                      front: (block.id, 3, .next),
                                      reservation: reservation)
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (block.id, 3, .next),
                                      back: (block.id, 2, .next),
                                      front: (block.id, 4, .next),
                                      reservation: reservation)

        // Next block feedback is triggered
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (nextBlock.id, 3, .previous),
                                      back: (block.id, 2, .next),
                                      front: (nextBlock.id, 3, .previous),
                                      reservation: reservation)
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (nextBlock.id, 3, .previous),
                                      back: (nextBlock.id, 3, .previous),
                                      front: (nextBlock.id, 3, .previous),
                                      reservation: reservation)
    }

    // MARK: - Train Backward -

    func testMoveBackwardSameBlock() throws {
        var location = TrainLocation()
        
        // Block (􁉆): [ p0 f0 p1 f1 p2 f2 p3 ]
        // Train (􀼮􀼯):           ??
        assertLocation(location, back: nil, front: nil)

        let reservation = Train.Reservation()
        let block = Block()
        reservation.occupied.append(block)

        // Block (􁉆): [ p0 |f0| p1 f1 p2 f2 p3 ]
        // Train (􀼮􀼯):        fb
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (block.id, 0, .next),
                                      back: (block.id, 1, .next),
                                      front: (block.id, 1, .next),
                                      reservation: reservation)

        // Block (􁉆): [ p0 f0 p1 |f1| p2 f2 p3 ]
        // Train (􀼮􀼯):              fb
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (block.id, 1, .next),
                                      back: (block.id, 2, .next),
                                      front: (block.id, 2, .next),
                                      reservation: reservation)

        // Block (􁉆): [ p0 |f0| p1 f1 p2 f2 p3 ]
        // Train (􀼮􀼯):        f     b
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (block.id, 0, .next),
                                      back: (block.id, 2, .next),
                                      front: (block.id, 1, .next),
                                      reservation: reservation)

        // Block (􁉆): [ p0 f0 p1 f1 p2 |f2| p3 ]
        // Train (􀼮􀼯):      f             b
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (block.id, 2, .next),
                                      back: (block.id, 3, .next),
                                      front: (block.id, 1, .next),
                                      reservation: reservation)
    }

    func testMoveBackwardSameBlockPrevious() throws {
        var location = TrainLocation()
        
        // Block (􁉈): [ p3 f2 p2 f1 p1 f0 p0 ]
        // Train (􀼮􀼯):           ??
        assertLocation(location, back: nil, front: nil)

        let reservation = Train.Reservation()
        let block = Block()
        reservation.occupied.append(block)

        // Block (􁉈): [ p3 |f2| p2 f1 p1 f0 p0 ]
        // Train (􀼮􀼯):        fb
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (block.id, 2, .previous),
                                      back: (block.id, 2, .previous),
                                      front: (block.id, 2, .previous),
                                      reservation: reservation)

        // Block (􁉈): [ p3 f2 p2 |f1| p1 f0 p0 ]
        // Train (􀼮􀼯):              fb
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (block.id, 1, .previous),
                                      back: (block.id, 1, .previous),
                                      front: (block.id, 1, .previous),
                                      reservation: reservation)

        // Block (􁉈): [ p3 |f2| p2 f1 p1 f0 p0 ]
        // Train (􀼮􀼯):        f     b
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (block.id, 2, .previous),
                                      back: (block.id, 1, .previous),
                                      front: (block.id, 2, .previous),
                                      reservation: reservation)

        // Block (􁉈): [ p3 f2 p2 f1 p1 |f0| p0 ]
        // Train (􀼮􀼯):      f             b
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (block.id, 0, .previous),
                                      back: (block.id, 0, .previous),
                                      front: (block.id, 2, .previous),
                                      reservation: reservation)
    }

    func testMoveBackwardNextBlock() throws {
        var location = TrainLocation()
        assertLocation(location, back: nil, front: nil)

        let reservation = Train.Reservation()
        let block = Block()
        reservation.occupied.append(block)
        let nextBlock = Block()
        reservation.leading.append(nextBlock)

        location = try assertFeedback(forward: false, location: location,
                                      feedback: (block.id, 1, .next),
                                      back: (block.id, 2, .next),
                                      front: (block.id, 2, .next),
                                      reservation: reservation)
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (block.id, 2, .next),
                                      back: (block.id, 3, .next),
                                      front: (block.id, 3, .next),
                                      reservation: reservation)
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (block.id, 1, .next),
                                      back: (block.id, 3, .next),
                                      front: (block.id, 2, .next),
                                      reservation: reservation)
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (block.id, 3, .next),
                                      back: (block.id, 4, .next),
                                      front: (block.id, 2, .next),
                                      reservation: reservation)
        
        // Next block feedback is triggered
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (nextBlock.id, 0, .next),
                                      back: (nextBlock.id, 1, .next),
                                      front: (block.id, 2, .next),
                                      reservation: reservation)
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (nextBlock.id, 0, .next),
                                      back: (nextBlock.id, 1, .next),
                                      front: (nextBlock.id, 1, .next),
                                      reservation: reservation)
    }
    
    func testMoveBackwardNextBlockPreviousDirection() throws {
        var location = TrainLocation()
        assertLocation(location, back: nil, front: nil)

        let reservation = Train.Reservation()
        let block = Block()
        reservation.occupied.append(block)
        let nextBlock = Block()
        reservation.leading.append(nextBlock)

        location = try assertFeedback(forward: false, location: location,
                                      feedback: (block.id, 1, .next),
                                      back: (block.id, 2, .next),
                                      front: (block.id, 2, .next),
                                      reservation: reservation)
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (block.id, 2, .next),
                                      back: (block.id, 3, .next),
                                      front: (block.id, 3, .next),
                                      reservation: reservation)
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (block.id, 1, .next),
                                      back: (block.id, 3, .next),
                                      front: (block.id, 2, .next),
                                      reservation: reservation)
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (block.id, 3, .next),
                                      back: (block.id, 4, .next),
                                      front: (block.id, 2, .next),
                                      reservation: reservation)
        
        // Next block feedback is triggered
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (nextBlock.id, 3, .previous),
                                      back: (nextBlock.id, 3, .previous),
                                      front: (block.id, 2, .next),
                                      reservation: reservation)
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (nextBlock.id, 3, .previous),
                                      back: (nextBlock.id, 3, .previous),
                                      front: (nextBlock.id, 3, .previous),
                                      reservation: reservation)
    }

    // MARK: - Helper -

    private func assertFeedback(forward: Bool, location currentLocation: TrainLocation, feedback: (Identifier<Block>, Int, Direction), back: (Identifier<Block>, Int, Direction)?, front: (Identifier<Block>, Int, Direction)?, reservation: Train.Reservation) throws -> TrainLocation {
        let feedback = TrainLocation.FeedbackPosition(blockId: feedback.0, index: feedback.1, direction: feedback.2)
        let backPosition: TrainPosition?
        if let back = back {
            backPosition = TrainPosition(blockId: back.0, index: back.1, direction: back.2)
        } else {
            backPosition = nil
        }
        let frontPosition: TrainPosition?
        if let front = front {
            frontPosition = TrainPosition(blockId: front.0, index: front.1, direction: front.2)
        } else {
            frontPosition = nil
        }
        return try assertFeedback(forward: forward, location: currentLocation, feedback: feedback, back: backPosition, front: frontPosition, reservation: reservation)
    }

    private func assertFeedback(forward: Bool, location currentLocation: TrainLocation, feedback feedbackIndex: TrainLocation.FeedbackPosition, back: TrainPosition?, front: TrainPosition?, reservation: Train.Reservation) throws -> TrainLocation {
        let newLocation = try TrainLocation.newLocationWith(trainMovesForward: forward, currentLocation: currentLocation, feedbackIndex: feedbackIndex, reservation: reservation)
        
        assertLocation(newLocation, back: back, front: front)

        return newLocation
    }
    
    private func assertLocation(_ location: TrainLocation, back: TrainPosition?, front: TrainPosition?) {
        XCTAssertEqual(location.back, back)
        XCTAssertEqual(location.front, front)
    }
}
