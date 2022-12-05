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

        let nextBlockPosition = TrainPosition(blockId: p.b2.id, index: 1, distance: 0)
        let currentBlockPosition = TrainPosition(blockId: p.b1.id, index: 1, distance: 0)
        XCTAssertTrue(try nextBlockPosition.isAfter(currentBlockPosition, reservation: p.reservation))
        
        p.moveToNextBlock(with: .next)
        XCTAssertEqual(p.reservation.occupied.blocks, [p.b2, p.b1])
        XCTAssertEqual(p.reservation.leading.blocks, [])
        
        let p1 = TrainPosition(blockId: p.b2.id, index: 1, distance: 0)
        let p2 = TrainPosition(blockId: p.b2.id, index: 1, distance: 50)
        XCTAssertTrue(try p2.isAfter(p1, reservation: p.reservation))
        
        let p3 = TrainPosition(blockId: p.b2.id, index: 1, distance: 50)
        let p4 = TrainPosition(blockId: p.b2.id, index: 1, distance: 0)
        XCTAssertFalse(try p4.isAfter(p3, reservation: p.reservation))
    }

    // MARK: - Train Forward -

    func testMoveForwardSameBlock() throws {
        var location = TrainPositions()
        
        // Block (􁉆): [ p0 f0 p1 f1 p2 f2 p3 ]
        // Train (􀼯􀼮):           ??
        assertLocation(location, back: nil, front: nil)

        let reservation = Train.Reservation()
        let block = Block(name: "b")
        block.trainInstance = TrainInstance(.init(uuid: "t1"), .next)
        reservation.occupied.append(block)
        
        // Block (􁉆): [ p0 |f0| p1 f1 p2 f2 p3 ]
        // Train (􀼯􀼮):        bf
        location = try assertForward(location: location,
                                     feedback: (block.id, 0, 10),
                                     front: (block.id, 1, 10),
                                     reservation: reservation)
        
        // Block (􁉆): [ p0 f0 p1 |f1| p2 f2 p3 ]
        // Train (􀼯􀼮):      b       f
        location = try assertForward(location: location,
                                     feedback: (block.id, 1, 20),
                                     front: (block.id, 2, 20),
                                     reservation: reservation)
        
        // Block (􁉆): [ p0 |f0| p1 f1 p2 f2 p3 ]
        // Train (􀼯􀼮):        b     f
        location = try assertForward(location: location,
                                     feedback: (block.id, 0, 10),
                                     front: (block.id, 2, 20),
                                     reservation: reservation)
        
        // Block (􁉆): [ p0 f0 p1 f1 p2 |f2| p3 ]
        // Train (􀼯􀼮):      b             f
        location = try assertForward(location: location,
                                     feedback: (block.id, 2, 30),
                                     front: (block.id, 3, 30),
                                     reservation: reservation)
    }

    func testMoveForwardSameBlockPrevious() throws {
        var location = TrainPositions()
        
        // Block (􁉈): [ p3 f2 p2 f1 p1 f0 p0 ]
        // Train (􀼯􀼮):           ??
        assertLocation(location, back: nil, front: nil)

        let reservation = Train.Reservation()
        let block = Block()
        block.trainInstance = TrainInstance(.init(uuid: "t1"), .previous)
        reservation.occupied.append(block)

        // Block (􁉈): [ p3 |f2| p2 f1 p1 f0 p0 ]
        // Train (􀼯􀼮):        bf
        location = try assertForward(location: location,
                                     feedback: (block.id, 2, 30),
                                     front: (block.id, 2, 30),
                                     reservation: reservation)
        
        // Block (􁉈): [ p3 f2 p2 |f1| p1 f0 p0 ]
        // Train (􀼯􀼮):      b       f
        location = try assertForward(location: location,
                                     feedback: (block.id, 1, 20),
                                     front: (block.id, 1, 20),
                                     reservation: reservation)
        
        // Block (􁉈): [ p3 |f2| p2 f1 p1 f0 p0 ]
        // Train (􀼯􀼮):        b     f
        location = try assertForward(location: location,
                                     feedback: (block.id, 2, 30),
                                     front: (block.id, 1, 20),
                                     reservation: reservation)
        
        // Block (􁉈): [ p3 f2 p2 f1 p1 |f0| p0 ]
        // Train (􀼯􀼮):      b             f
        location = try assertForward(location: location,
                                     feedback: (block.id, 0, 10),
                                     front: (block.id, 0, 10),
                                     reservation: reservation)
    }

    func testMoveForwardNextBlock() throws {
        var location = TrainPositions()
        assertLocation(location, back: nil, front: nil)

        let p = Package()

        location = try assertForward(location: location,
                                     feedback: (p.b1.id, 1, 20),
                                     front: (p.b1.id, 2, 20),
                                     reservation: p.reservation)
        location = try assertForward(location: location,
                                     feedback: (p.b1.id, 2, 30),
                                     front: (p.b1.id, 3, 30),
                                     reservation: p.reservation)
        location = try assertForward(location: location,
                                     feedback: (p.b1.id, 1, 20),
                                     front: (p.b1.id, 3, 30),
                                     reservation: p.reservation)
        location = try assertForward(location: location,
                                     feedback: (p.b1.id, 3, 40),
                                     front: (p.b1.id, 4, 40),
                                     reservation: p.reservation)
        
        // Next block feedback is triggered
        location = try assertForward(location: location,
                                     feedback: (p.b2.id, 0, 10),
                                     front: (p.b2.id, 1, 10),
                                     reservation: p.reservation,
                                     nextBlockTrainDirection: .next)
        
        p.moveToNextBlock(with: .next)
        
        location = try assertForward(location: location,
                                     feedback: (p.b2.id, 0, 10),
                                     front: (p.b2.id, 1, 10),
                                     reservation: p.reservation)
    }

    func testMoveForwardNextBlockPreviousDirection() throws {
        var location = TrainPositions()
        assertLocation(location, back: nil, front: nil)

        let p = Package()

        location = try assertForward(location: location,
                                     feedback: (p.b1.id, 1, 10),
                                     front: (p.b1.id, 2, 10),
                                     reservation: p.reservation)
        location = try assertForward(location: location,
                                     feedback: (p.b1.id, 2, 20),
                                     front: (p.b1.id, 3, 20),
                                     reservation: p.reservation)
        location = try assertForward(location: location,
                                     feedback: (p.b1.id, 1, 10),
                                     front: (p.b1.id, 3, 20),
                                     reservation: p.reservation)
        location = try assertForward(location: location,
                                     feedback: (p.b1.id, 3, 30),
                                     front: (p.b1.id, 4, 30),
                                     reservation: p.reservation)
        
        // Next block feedback is triggered
        location = try assertForward(location: location,
                                     feedback: (p.b2.id, 3, 30),
                                     front: (p.b2.id, 3, 30),
                                     reservation: p.reservation,
                                     nextBlockTrainDirection: .previous)
        p.moveToNextBlock(with: .previous)
        location = try assertForward(location: location,
                                     feedback: (p.b2.id, 3, 30),
                                     front: (p.b2.id, 3, 30),
                                     reservation: p.reservation)
    }

    // MARK: - Multi-block occupation
    
    func testMoveForwardSameBlocksNextNext() throws {
        let reservation = Train.Reservation()
        let b1 = Block(name: "b1")
        b1.trainInstance = TrainInstance(.init(uuid: "t1"), .next)
        let b2 = Block(name: "b2")
        b2.trainInstance = TrainInstance(.init(uuid: "t1"), .next)
        
        // Reserved blocks are always ordered starting with the front of the train
        // (in the direction of travel of the train)
        reservation.occupied.append(b2)
        reservation.occupied.append(b1)

        var lines = [LineForwardAssertion]()

        // Blocks (􁉆􁉆): b1[ p0 f0 p1 f1 p2 f2 p3 ] b2[ p0 |f0| p1 f1 p2 f2 p3 ]
        // Train (􀼯􀼮):                                        bf
        lines.append(LineForwardAssertion(feedback: (b2.id, 0, 10), front: (b2.id, 1, 10)))

        // Block (􁉆􁉆): b1[ p0 f0 p1 |f1| p2 f2 p3 ] b2[ p0 f0 p1 f1 p2 f2 p3 ]
        // Train (􀼯􀼮):                  b                    f
        lines.append(LineForwardAssertion(feedback: (b1.id, 1, 20), front: (b2.id, 1, 10)))

        // Block (􁉆􁉆): b1[ p0 f0 p1 f1 p2 f2 p3 ] b2[ p0 f0 p1 f1 p2 |f2| p3 ]
        // Train (􀼯􀼮):                b                                  f
        lines.append(LineForwardAssertion(feedback: (b2.id, 2, 30), front: (b2.id, 3, 30)))

        // Block (􁉆􁉆): b1[ p0 f0 p1 f1 p2 f2 p3 ] b2[ p0 |f0| p1 f1 p2 f2 p3 ]
        // Train (􀼯􀼮):                                       b           f
        lines.append(LineForwardAssertion(feedback: (b2.id, 0, 10), front: (b2.id, 3, 30)))
        
        try assertLines(lines: lines, reservation: reservation)
    }

    func testMoveForwardSameBlocksNextPrevious() throws {
        let reservation = Train.Reservation()
        let b1 = Block(name: "b1")
        b1.trainInstance = TrainInstance(.init(uuid: "t1"), .next)
        let b2 = Block(name: "b2")
        b2.trainInstance = TrainInstance(.init(uuid: "t1"), .previous)
        
        // Reserved blocks are always ordered starting with the front of the train
        // (in the direction of travel of the train)
        reservation.occupied.append(b2)
        reservation.occupied.append(b1)

        var lines = [LineForwardAssertion]()

        // Blocks (􁉆􁉈): b1[ p0 f0 p1 f1 p2 f2 p3 ] b2[ p3 |f2| p2 f1 p1 f0 p0 ]
        // Train (􀼯􀼮):                                        bf
        lines.append(LineForwardAssertion(feedback: (b2.id, 2, 30), front: (b2.id, 2, 30)))

        // Blocks (􁉆􁉈): b1[ p0 f0 p1 |f1| p2 f2 p3 ] b2[ p3 f2 p2 f1 p1 f0 p0 ]
        // Train (􀼯􀼮):                   b                    f
        lines.append(LineForwardAssertion(feedback: (b1.id, 1, 20), front: (b2.id, 2, 30)))

        // Blocks (􁉆􁉈): b1[ p0 f0 p1 f1 p2 f2 p3 ] b2[ p3 f2 p2 f1 p1 |f0| p0 ]
        // Train (􀼯􀼮):                 b                                  f
        lines.append(LineForwardAssertion(feedback: (b2.id, 0, 10), front: (b2.id, 0, 10)))

        // Blocks (􁉆􁉈): b1[ p0 f0 p1 f1 p2 f2 p3 ] b2[ p3 |f2| p2 f1 p1 f0 p0 ]
        // Train (􀼯􀼮):                                        b           f
        lines.append(LineForwardAssertion(feedback: (b2.id, 2, 20), front: (b2.id, 0, 10)))
                
        try assertLines(lines: lines, reservation: reservation)
    }

    func testMoveForwardSameBlocksPreviousNext() throws {
        let reservation = Train.Reservation()
        let b1 = Block(name: "b1")
        b1.trainInstance = TrainInstance(.init(uuid: "t1"), .previous)
        let b2 = Block(name: "b2")
        b2.trainInstance = TrainInstance(.init(uuid: "t1"), .next)
        
        // Reserved blocks are always ordered starting with the front of the train
        // (in the direction of travel of the train)
        reservation.occupied.append(b2)
        reservation.occupied.append(b1)

        var lines = [LineForwardAssertion]()

        // Blocks (􁉈􁉆): b1[ p3 f2 p2 f1 p1 f0 p0 ] b2[ p0 |f0| p1 f1 p2 f2 p3 ]
        // Train (􀼯􀼮):                                        bf
        lines.append(LineForwardAssertion(feedback: (b2.id, 0, 10), front: (b2.id, 1, 10)))

        // Blocks (􁉈􁉆): b1[ p3 f2 p2 |f1| p1 f0 p0 ] b2[ p0 f0 p1 f1 p2 f2 p3 ]
        // Train (􀼯􀼮):                   b                    f
        lines.append(LineForwardAssertion(feedback: (b1.id, 1, 20), front: (b2.id, 1, 10)))

        // Blocks (􁉈􁉆): b1[ p3 f2 p2 f1 p1 f0 p0 ] b2[ p0 f0 p1 |f1| p2 f2 p3 ]
        // Train (􀼯􀼮):                 b                            f
        lines.append(LineForwardAssertion(feedback: (b2.id, 1, 20), front: (b2.id, 2, 20)))

        // Blocks (􁉈􁉆): b1[ p3 f2 p2 f1 p1 f0 p0 ] b2[ p0 |f0| p1 f1 p2 f2 p3 ]
        // Train (􀼯􀼮):                                        b     f
        lines.append(LineForwardAssertion(feedback: (b2.id, 0, 10), front: (b2.id, 2, 20)))
                
        try assertLines(lines: lines, reservation: reservation)
    }

    func testMoveForwardSameBlocksPreviousPrevious() throws {
        let reservation = Train.Reservation()
        let b1 = Block(name: "b1")
        b1.trainInstance = TrainInstance(.init(uuid: "t1"), .previous)
        let b2 = Block(name: "b2")
        b2.trainInstance = TrainInstance(.init(uuid: "t1"), .previous)
        
        // Reserved blocks are always ordered starting with the front of the train
        // (in the direction of travel of the train)
        reservation.occupied.append(b2)
        reservation.occupied.append(b1)

        var lines = [LineForwardAssertion]()

        // Blocks (􁉈􁉆): b1[ p3 f2 p2 f1 p1 f0 p0 ] b2[ p3 |f2| p2 f1 p1 f0 p0 ]
        // Train (􀼯􀼮):                                        bf
        lines.append(LineForwardAssertion(feedback: (b2.id, 2, 20), front: (b2.id, 2, 20)))

        // Blocks (􁉈􁉆): b1[ p3 f2 p2 |f1| p1 f0 p0 ] b2[ p3 f2 p2 f1 p1 f0 p0 ]
        // Train (􀼯􀼮):                   b                    f
        lines.append(LineForwardAssertion(feedback: (b1.id, 1, 10), front: (b2.id, 2, 20)))

        // Blocks (􁉈􁉆): b1[ p3 f2 p2 f1 p1 f0 p0 ] b2[ p3 f2 p2 |f1| p1 f0 p0 ]
        // Train (􀼯􀼮):                 b                            f
        lines.append(LineForwardAssertion(feedback: (b2.id, 1, 10), front: (b2.id, 1, 10)))

        // Blocks (􁉈􁉆): b1[ p3 f2 p2 f1 p1 f0 p0 ] b2[ p3 |f2| p2 f1 p1 f0 p0 ]
        // Train (􀼯􀼮):                                        b     f
        lines.append(LineForwardAssertion(feedback: (b2.id, 2, 20), front: (b2.id, 1, 10)))
                
        try assertLines(lines: lines, reservation: reservation)
    }

    struct LineForwardAssertion {
        let feedback: (Identifier<Block>, Int, Double)
        let front: (Identifier<Block>, Int, Double)
    }
        
    private func assertLines(lines: [LineForwardAssertion], reservation: Train.Reservation) throws {
        var location = TrainPositions()
        
        // Train (􀼯􀼮):           ??
        assertLocation(location, back: nil, front: nil)

        for line in lines {
            location = try assertForward(location: location,
                                         feedback: line.feedback,
                                         front: line.front,
                                         reservation: reservation)
        }
    }
    
    // MARK: - Train Backward -

    func testMoveBackwardSameBlock() throws {
        var location = TrainPositions()
        
        // Block (􁉆): [ p0 f0 p1 f1 p2 f2 p3 ]
        // Train (􀼮􀼯):           ??
        assertLocation(location, back: nil, front: nil)

        let reservation = Train.Reservation()
        let block = Block()
        block.trainInstance = TrainInstance(.init(uuid: "t1"), .next)
        reservation.occupied.append(block)

        // Block (􁉆): [ p0 |f0| p1 f1 p2 f2 p3 ]
        // Train (􀼮􀼯):        fb
        location = try assertBackward(location: location,
                                      feedback: (block.id, 0, 10),
                                      back: (block.id, 1, 10),
                                      reservation: reservation)

        // Block (􁉆): [ p0 f0 p1 |f1| p2 f2 p3 ]
        // Train (􀼮􀼯):      f       b
        location = try assertBackward(location: location,
                                      feedback: (block.id, 1, 20),
                                      back: (block.id, 2, 20),
                                      reservation: reservation)

        // Block (􁉆): [ p0 |f0| p1 f1 p2 f2 p3 ]
        // Train (􀼮􀼯):        f     b
        location = try assertBackward(location: location,
                                      feedback: (block.id, 0, 10),
                                      back: (block.id, 2, 20),
                                      reservation: reservation)

        // Block (􁉆): [ p0 f0 p1 f1 p2 |f2| p3 ]
        // Train (􀼮􀼯):      f             b
        location = try assertBackward(location: location,
                                      feedback: (block.id, 2, 30),
                                      back: (block.id, 3, 30),
                                      reservation: reservation)
    }

    func testMoveBackwardSameBlockPrevious() throws {
        var location = TrainPositions()
        
        // Block (􁉈): [ p3 f2 p2 f1 p1 f0 p0 ]
        // Train (􀼮􀼯):           ??
        assertLocation(location, back: nil, front: nil)

        let reservation = Train.Reservation()
        let block = Block()
        block.trainInstance = TrainInstance(.init(uuid: "t1"), .previous)
        reservation.occupied.append(block)

        // Block (􁉈): [ p3 |f2| p2 f1 p1 f0 p0 ]
        // Train (􀼮􀼯):        fb
        location = try assertBackward(location: location,
                                      feedback: (block.id, 2, 30),
                                      back: (block.id, 2, 30),
                                      reservation: reservation)

        // Block (􁉈): [ p3 f2 p2 |f1| p1 f0 p0 ]
        // Train (􀼮􀼯):      f       b
        location = try assertBackward(location: location,
                                      feedback: (block.id, 1, 20),
                                      back: (block.id, 1, 20),
                                      reservation: reservation)

        // Block (􁉈): [ p3 |f2| p2 f1 p1 f0 p0 ]
        // Train (􀼮􀼯):        f     b
        location = try assertBackward(location: location,
                                      feedback: (block.id, 2, 30),
                                      back: (block.id, 1, 20),
                                      reservation: reservation)

        // Block (􁉈): [ p3 f2 p2 f1 p1 |f0| p0 ]
        // Train (􀼮􀼯):      f             b
        location = try assertBackward(location: location,
                                      feedback: (block.id, 0, 10),
                                      back: (block.id, 0, 10),
                                      reservation: reservation)
    }

    func testMoveBackwardNextBlock() throws {
        var location = TrainPositions()
        assertLocation(location, back: nil, front: nil)

        let p = Package()

        location = try assertBackward(location: location,
                                      feedback: (p.b1.id, 1, 20),
                                      back: (p.b1.id, 2, 20),
                                      reservation: p.reservation)
        location = try assertBackward(location: location,
                                      feedback: (p.b1.id, 2, 30),
                                      back: (p.b1.id, 3, 30),
                                      reservation: p.reservation)
        location = try assertBackward(location: location,
                                      feedback: (p.b1.id, 1, 20),
                                      back: (p.b1.id, 3, 30),
                                      reservation: p.reservation)
        location = try assertBackward(location: location,
                                      feedback: (p.b1.id, 3, 40),
                                      back: (p.b1.id, 4, 40),
                                      reservation: p.reservation)
        
        // Next block feedback is triggered
        location = try assertBackward(location: location,
                                      feedback: (p.b2.id, 0, 10),
                                      back: (p.b2.id, 1, 10),
                                      reservation: p.reservation,
                                      nextBlockTrainDirection: .next)
        
        p.moveToNextBlock(with: .next)

        location = try assertBackward(location: location,
                                      feedback: (p.b2.id, 0, 10),
                                      back: (p.b2.id, 1, 10),
                                      reservation: p.reservation)
    }

    func testMoveBackwardNextBlockPreviousDirection() throws {
        var location = TrainPositions()
        assertLocation(location, back: nil, front: nil)

        let p = Package()

        location = try assertBackward(location: location,
                                      feedback: (p.b1.id, 1, 20),
                                      back: (p.b1.id, 2, 20),
                                      reservation: p.reservation)
        location = try assertBackward(location: location,
                                      feedback: (p.b1.id, 2, 30),
                                      back: (p.b1.id, 3, 30),
                                      reservation: p.reservation)
        location = try assertBackward(location: location,
                                      feedback: (p.b1.id, 1, 20),
                                      back: (p.b1.id, 3, 30),
                                      reservation: p.reservation)
        location = try assertBackward(location: location,
                                      feedback: (p.b1.id, 3, 40),
                                      back: (p.b1.id, 4, 40),
                                      reservation: p.reservation)
        
        // Next block feedback is triggered
        location = try assertBackward(location: location,
                                      feedback: (p.b2.id, 3, 40),
                                      back: (p.b2.id, 3, 40),
                                      reservation: p.reservation,
                                      nextBlockTrainDirection: .previous)
        
        p.moveToNextBlock(with: .previous)
        
        location = try assertBackward(location: location,
                                      feedback: (p.b2.id, 3, 40),
                                      back: (p.b2.id, 3, 40),
                                      reservation: p.reservation)
    }
    
    // MARK: - Helper -

    private struct Package {
        
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
    
    private func assertForward(location currentPositions: TrainPositions, feedback: (Identifier<Block>, Int, Double), front: (Identifier<Block>, Int, Double)?, reservation: Train.Reservation, nextBlockTrainDirection: Direction? = nil) throws -> TrainPositions {
        let direction = try reservation.directionInBlock(for: feedback.0) ?? nextBlockTrainDirection!
        let detectedPosition: TrainPosition
        if direction == .next {
            detectedPosition = TrainPosition(blockId: feedback.0, index: feedback.1+1, distance: feedback.2)
        } else {
            detectedPosition = TrainPosition(blockId: feedback.0, index: feedback.1, distance: feedback.2)
        }
        let frontPosition: TrainPosition?
        if let front = front {
            frontPosition = TrainPosition(blockId: front.0, index: front.1, distance: front.2)
        } else {
            frontPosition = nil
        }
        
        let newLocation = try currentPositions.newPositionsWith(trainMovesForward: true, detectedPosition: detectedPosition, reservation: reservation)
        
        assertLocation(newLocation, back: nil, front: frontPosition)

        return newLocation
    }
    
    private func assertBackward(location currentPositions: TrainPositions, feedback: (Identifier<Block>, Int, Double), back: (Identifier<Block>, Int, Double)?, reservation: Train.Reservation, nextBlockTrainDirection: Direction? = nil) throws -> TrainPositions {
        let direction = try reservation.directionInBlock(for: feedback.0) ?? nextBlockTrainDirection!
        let detectedPosition: TrainPosition
        if direction == .next {
            detectedPosition = TrainPosition(blockId: feedback.0, index: feedback.1+1, distance: feedback.2)
        } else {
            detectedPosition = TrainPosition(blockId: feedback.0, index: feedback.1, distance: feedback.2)
        }
        let backPosition: TrainPosition?
        if let back = back {
            backPosition = TrainPosition(blockId: back.0, index: back.1, distance: back.2)
        } else {
            backPosition = nil
        }
        let newLocation = try currentPositions.newPositionsWith(trainMovesForward: false, detectedPosition: detectedPosition, reservation: reservation)
        
        assertLocation(newLocation, back: backPosition, front: nil)

        return newLocation
    }
    
    private func assertLocation(_ location: TrainPositions, back: TrainPosition?, front: TrainPosition?) {
        XCTAssertEqual(location.back, back, "Back position mismatch")
        XCTAssertEqual(location.front, front, "Front position mismatch")
    }
 
}
