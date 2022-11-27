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

    // MARK: - Individual Functions -
    
    func testIsAfterFunction() throws {
        let p = Package()
        XCTAssertEqual(p.reservation.occupied.blocks, [p.b1])
        XCTAssertEqual(p.reservation.leading.blocks, [p.b2])

        let nextBlockPosition = TrainPosition(blockId: p.b2.id, index: 1)
        let currentBlockPosition = TrainPosition(blockId: p.b1.id, index: 1)
        XCTAssertTrue(try nextBlockPosition.isAfter(currentBlockPosition, reservation: p.reservation, direction: .next))
        
        p.moveToNextBlock(with: .next)
        XCTAssertEqual(p.reservation.occupied.blocks, [p.b2, p.b1])
        XCTAssertEqual(p.reservation.leading.blocks, [])
    }
    
    // MARK: - Train Forward -

    // TODO: also test when a train spans more than one block (occupied.blocks.count > 1)
    func testMoveForwardSameBlock() throws {
        var location = TrainLocation()
        
        // Block (􁉆): [ p0 f0 p1 f1 p2 f2 p3 ]
        // Train (􀼯􀼮):           ??
        assertLocation(location, back: nil, front: nil)

        let reservation = Train.Reservation()
        let block = Block()
        block.trainInstance = TrainInstance(.init(uuid: "t1"), .next)
        reservation.occupied.append(block)
        
        // Block (􁉆): [ p0 |f0| p1 f1 p2 f2 p3 ]
        // Train (􀼯􀼮):        bf
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (block.id, 0),
                                      back: (block.id, 1),
                                      front: (block.id, 1),
                                      reservation: reservation)

        // Block (􁉆): [ p0 f0 p1 |f1| p2 f2 p3 ]
        // Train (􀼯􀼮):      b       f
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (block.id, 1),
                                      back: (block.id, 1),
                                      front: (block.id, 2),
                                      reservation: reservation)

        // Block (􁉆): [ p0 |f0| p1 f1 p2 f2 p3 ]
        // Train (􀼯􀼮):        b     f
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (block.id, 0),
                                      back: (block.id, 1),
                                      front: (block.id, 2),
                                      reservation: reservation)

        // Block (􁉆): [ p0 f0 p1 f1 p2 |f2| p3 ]
        // Train (􀼯􀼮):      b             f
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (block.id, 2),
                                      back: (block.id, 1),
                                      front: (block.id, 3),
                                      reservation: reservation)
    }

    
    func testMoveForwardSameBlockPrevious() throws {
        var location = TrainLocation()
        
        // Block (􁉈): [ p3 f2 p2 f1 p1 f0 p0 ]
        // Train (􀼯􀼮):           ??
        assertLocation(location, back: nil, front: nil)

        let reservation = Train.Reservation()
        let block = Block()
        block.trainInstance = TrainInstance(.init(uuid: "t1"), .previous)
        reservation.occupied.append(block)

        // Block (􁉈): [ p3 |f2| p2 f1 p1 f0 p0 ]
        // Train (􀼯􀼮):        bf
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (block.id, 2),
                                      back: (block.id, 2),
                                      front: (block.id, 2),
                                      reservation: reservation)

        // Block (􁉈): [ p3 f2 p2 |f1| p1 f0 p0 ]
        // Train (􀼯􀼮):      b       f
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (block.id, 1),
                                      back: (block.id, 2),
                                      front: (block.id, 1),
                                      reservation: reservation)

        // Block (􁉈): [ p3 |f2| p2 f1 p1 f0 p0 ]
        // Train (􀼯􀼮):        b     f
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (block.id, 2),
                                      back: (block.id, 2),
                                      front: (block.id, 1),
                                      reservation: reservation)

        // Block (􁉈): [ p3 f2 p2 f1 p1 |f0| p0 ]
        // Train (􀼯􀼮):      b             f
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (block.id, 0),
                                      back: (block.id, 2),
                                      front: (block.id, 0),
                                      reservation: reservation)
    }

    func testMoveForwardNextBlock() throws {
        var location = TrainLocation()
        assertLocation(location, back: nil, front: nil)

        let p = Package()

        location = try assertFeedback(forward: true, location: location,
                                      feedback: (p.b1.id, 1),
                                      back: (p.b1.id, 2),
                                      front: (p.b1.id, 2),
                                      reservation: p.reservation)
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (p.b1.id, 2),
                                      back: (p.b1.id, 2),
                                      front: (p.b1.id, 3),
                                      reservation: p.reservation)
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (p.b1.id, 1),
                                      back: (p.b1.id, 2),
                                      front: (p.b1.id, 3),
                                      reservation: p.reservation)
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (p.b1.id, 3),
                                      back: (p.b1.id, 2),
                                      front: (p.b1.id, 4),
                                      reservation: p.reservation)

        // Next block feedback is triggered
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (p.b2.id, 0),
                                      back: (p.b1.id, 2),
                                      front: (p.b2.id, 1),
                                      reservation: p.reservation,
                                      nextBlockTrainDirection: .next)
        
        p.moveToNextBlock(with: .next)
        
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (p.b2.id, 0),
                                      back: (p.b2.id, 1),
                                      front: (p.b2.id, 1),
                                      reservation: p.reservation)
    }
    
    func testMoveForwardNextBlockPreviousDirection() throws {
        var location = TrainLocation()
        assertLocation(location, back: nil, front: nil)

        let p = Package()

        location = try assertFeedback(forward: true, location: location,
                                      feedback: (p.b1.id, 1),
                                      back: (p.b1.id, 2),
                                      front: (p.b1.id, 2),
                                      reservation: p.reservation)
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (p.b1.id, 2),
                                      back: (p.b1.id, 2),
                                      front: (p.b1.id, 3),
                                      reservation: p.reservation)
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (p.b1.id, 1),
                                      back: (p.b1.id, 2),
                                      front: (p.b1.id, 3),
                                      reservation: p.reservation)
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (p.b1.id, 3),
                                      back: (p.b1.id, 2),
                                      front: (p.b1.id, 4),
                                      reservation: p.reservation)

        // Next block feedback is triggered
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (p.b2.id, 3),
                                      back: (p.b1.id, 2),
                                      front: (p.b2.id, 3),
                                      reservation: p.reservation,
                                      nextBlockTrainDirection: .previous)
        p.moveToNextBlock(with: .previous)
        location = try assertFeedback(forward: true, location: location,
                                      feedback: (p.b2.id, 3),
                                      back: (p.b2.id, 3),
                                      front: (p.b2.id, 3),
                                      reservation: p.reservation)
    }

    // MARK: - Train Backward -

    func testMoveBackwardSameBlock() throws {
        var location = TrainLocation()
        
        // Block (􁉆): [ p0 f0 p1 f1 p2 f2 p3 ]
        // Train (􀼮􀼯):           ??
        assertLocation(location, back: nil, front: nil)

        let reservation = Train.Reservation()
        let block = Block()
        block.trainInstance = TrainInstance(.init(uuid: "t1"), .next)
        reservation.occupied.append(block)

        // Block (􁉆): [ p0 |f0| p1 f1 p2 f2 p3 ]
        // Train (􀼮􀼯):        fb
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (block.id, 0),
                                      back: (block.id, 1),
                                      front: (block.id, 1),
                                      reservation: reservation)

        // Block (􁉆): [ p0 f0 p1 |f1| p2 f2 p3 ]
        // Train (􀼮􀼯):      f       b
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (block.id, 1),
                                      back: (block.id, 2),
                                      front: (block.id, 1),
                                      reservation: reservation)

        // Block (􁉆): [ p0 |f0| p1 f1 p2 f2 p3 ]
        // Train (􀼮􀼯):        f     b
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (block.id, 0),
                                      back: (block.id, 2),
                                      front: (block.id, 1),
                                      reservation: reservation)

        // Block (􁉆): [ p0 f0 p1 f1 p2 |f2| p3 ]
        // Train (􀼮􀼯):      f             b
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (block.id, 2),
                                      back: (block.id, 3),
                                      front: (block.id, 1),
                                      reservation: reservation)
    }

    func testMoveBackwardSameBlockPrevious() throws {
        var location = TrainLocation()
        
        // Block (􁉈): [ p3 f2 p2 f1 p1 f0 p0 ]
        // Train (􀼮􀼯):           ??
        assertLocation(location, back: nil, front: nil)

        let reservation = Train.Reservation()
        let block = Block()
        block.trainInstance = TrainInstance(.init(uuid: "t1"), .previous)
        reservation.occupied.append(block)

        // Block (􁉈): [ p3 |f2| p2 f1 p1 f0 p0 ]
        // Train (􀼮􀼯):        fb
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (block.id, 2),
                                      back: (block.id, 2),
                                      front: (block.id, 2),
                                      reservation: reservation)

        // Block (􁉈): [ p3 f2 p2 |f1| p1 f0 p0 ]
        // Train (􀼮􀼯):      f       b
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (block.id, 1),
                                      back: (block.id, 1),
                                      front: (block.id, 2),
                                      reservation: reservation)

        // Block (􁉈): [ p3 |f2| p2 f1 p1 f0 p0 ]
        // Train (􀼮􀼯):        f     b
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (block.id, 2),
                                      back: (block.id, 1),
                                      front: (block.id, 2),
                                      reservation: reservation)

        // Block (􁉈): [ p3 f2 p2 f1 p1 |f0| p0 ]
        // Train (􀼮􀼯):      f             b
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (block.id, 0),
                                      back: (block.id, 0),
                                      front: (block.id, 2),
                                      reservation: reservation)
    }

    func testMoveBackwardNextBlock() throws {
        var location = TrainLocation()
        assertLocation(location, back: nil, front: nil)

        let p = Package()

        location = try assertFeedback(forward: false, location: location,
                                      feedback: (p.b1.id, 1),
                                      back: (p.b1.id, 2),
                                      front: (p.b1.id, 2),
                                      reservation: p.reservation)
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (p.b1.id, 2),
                                      back: (p.b1.id, 3),
                                      front: (p.b1.id, 2),
                                      reservation: p.reservation)
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (p.b1.id, 1),
                                      back: (p.b1.id, 3),
                                      front: (p.b1.id, 2),
                                      reservation: p.reservation)
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (p.b1.id, 3),
                                      back: (p.b1.id, 4),
                                      front: (p.b1.id, 2),
                                      reservation: p.reservation)
        
        // Next block feedback is triggered
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (p.b2.id, 0),
                                      back: (p.b2.id, 1),
                                      front: (p.b1.id, 2),
                                      reservation: p.reservation,
                                      nextBlockTrainDirection: .next)
        
        p.moveToNextBlock(with: .next)

        location = try assertFeedback(forward: false, location: location,
                                      feedback: (p.b2.id, 0),
                                      back: (p.b2.id, 1),
                                      front: (p.b2.id, 1),
                                      reservation: p.reservation)
    }
    
    func testMoveBackwardNextBlockPreviousDirection() throws {
        var location = TrainLocation()
        assertLocation(location, back: nil, front: nil)

        let p = Package()

        location = try assertFeedback(forward: false, location: location,
                                      feedback: (p.b1.id, 1),
                                      back: (p.b1.id, 2),
                                      front: (p.b1.id, 2),
                                      reservation: p.reservation)
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (p.b1.id, 2),
                                      back: (p.b1.id, 3),
                                      front: (p.b1.id, 2),
                                      reservation: p.reservation)
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (p.b1.id, 1),
                                      back: (p.b1.id, 3),
                                      front: (p.b1.id, 2),
                                      reservation: p.reservation)
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (p.b1.id, 3),
                                      back: (p.b1.id, 4),
                                      front: (p.b1.id, 2),
                                      reservation: p.reservation)
        
        // Next block feedback is triggered
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (p.b2.id, 3),
                                      back: (p.b2.id, 3),
                                      front: (p.b1.id, 2),
                                      reservation: p.reservation,
                                      nextBlockTrainDirection: .previous)
        
        p.moveToNextBlock(with: .previous)
        
        location = try assertFeedback(forward: false, location: location,
                                      feedback: (p.b2.id, 3),
                                      back: (p.b2.id, 3),
                                      front: (p.b2.id, 3),
                                      reservation: p.reservation)
    }

    // MARK: - Helper -

    struct Package {
        
        let reservation = Train.Reservation()
        let b1 = Block(name: "b1")
        let b2 = Block(name: "b2")
        
        init() {
            b1.trainInstance = TrainInstance(.init(uuid: "t1"), .next)
            reservation.occupied.append(b1)
            reservation.leading.append(b2)
        }
        
        func moveToNextBlock(with direction: Direction) {
            b2.trainInstance = TrainInstance(.init(uuid: "t1"), direction)
            reservation.occupied.clear()
            reservation.leading.clear()
            reservation.occupied.append(b2)
            reservation.occupied.append(b1)
        }
    }
    
    private func assertFeedback(forward: Bool, location currentLocation: TrainLocation, feedback: (Identifier<Block>, Int), back: (Identifier<Block>, Int)?, front: (Identifier<Block>, Int)?, reservation: Train.Reservation, nextBlockTrainDirection: Direction? = nil) throws -> TrainLocation {
        let direction = reservation.directionInBlock(for: feedback.0) ?? nextBlockTrainDirection!
        let detectedPosition: TrainPosition
        if direction == .next {
            detectedPosition = TrainPosition(blockId: feedback.0, index: feedback.1+1)
        } else {
            detectedPosition = TrainPosition(blockId: feedback.0, index: feedback.1)
        }
        let backPosition: TrainPosition?
        if let back = back {
            backPosition = TrainPosition(blockId: back.0, index: back.1)
        } else {
            backPosition = nil
        }
        let frontPosition: TrainPosition?
        if let front = front {
            frontPosition = TrainPosition(blockId: front.0, index: front.1)
        } else {
            frontPosition = nil
        }
        return try assertFeedback(forward: forward, location: currentLocation, detectedPosition: detectedPosition, direction: direction, back: backPosition, front: frontPosition, reservation: reservation)
    }

    private func assertFeedback(forward: Bool, location currentLocation: TrainLocation, detectedPosition: TrainPosition, direction: Direction, back: TrainPosition?, front: TrainPosition?, reservation: Train.Reservation) throws -> TrainLocation {
        let newLocation = try Train.newLocationWith(trainMovesForward: forward, allowedDirection: .any, currentLocation: currentLocation, detectedPosition: detectedPosition, direction: direction, reservation: reservation)
        
        assertLocation(newLocation, back: back, front: front)

        return newLocation
    }
    
    private func assertLocation(_ location: TrainLocation, back: TrainPosition?, front: TrainPosition?) {
        XCTAssertEqual(location.back, back, "Back position mismatch")
        XCTAssertEqual(location.front, front, "Front position mismatch")
    }
}
