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

final class LayoutOccupationTests: XCTestCase {

    let ls = LayoutSample()
    
    // blocks:    b0[   ]>
    // indexes:       0
    // distances:    100
    // train:        -->    (length=20)
    func testOccupySingleBlockNext() throws {
        try ls.reserve(block: ls.b0, positions: .head(blockId: ls.b0.id, index: 0, distance: 50, direction: .next))
        ls.assert(ls.b0.trainInstance, .next, expectedParts: [0: .locomotive])
        XCTAssertEqual(ls.train.positions, .both(blockId: ls.b0.id, headIndex: 0, headDistance: 50, tailIndex: 0, tailDistance: 30, direction: .next))
    }

    func testOccupySingleBlockNextWithZeroLengthTrain() throws {
        ls.loc.length = 0
        ls.train.wagonsLength = 0
        try ls.reserve(block: ls.b0, positions: .head(blockId: ls.b0.id, index: 0, distance: 50, direction: .next))
        ls.assert(ls.b0.trainInstance, .next, expectedParts: [0: .locomotive])
        XCTAssertEqual(ls.train.positions, .both(blockId: ls.b0.id, headIndex: 0, headDistance: 50, tailIndex: 0, tailDistance: 50, direction: .next))
    }

    // blocks:    b0[   ]>
    // indexes:       0
    // distances:    100
    // train:         <--    (length=20)
    func testOccupySingleBlockPrevious() throws {
        try ls.reserve(block: ls.b0, positions: .head(blockId: ls.b0.id, index: 0, distance: 50, direction: .previous))
        ls.assert(ls.b0.trainInstance, .previous, expectedParts: [0: .locomotive])
        XCTAssertEqual(ls.train.positions, .both(blockId: ls.b0.id, headIndex: 0, headDistance: 50, tailIndex: 0, tailDistance: 70, direction: .previous))
    }

    // blocks:    b0[   ]> b1[   f0   ]>
    // indexes:       0        0    1
    // distances:    100      50   50
    // train:         ------------->    (length=120)
    func testOccupyTwoBlocksNext() throws {
        ls.loc.length = 20
        ls.train.wagonsLength = 100
        try ls.reserve(block: ls.b1, positions: .head(blockId: ls.b1.id, index: 1, distance: 50, direction: .next))

        ls.assert(ls.b0.trainInstance, .next, expectedParts: [0: .wagon])
        ls.assert(ls.b1.trainInstance, .next, expectedParts: [0: .locomotive])
        XCTAssertEqual(ls.train.positions, TrainPositions(head: .init(blockId: ls.b1.id, index: 1, distance: 50, direction: .next),
                                                          tail: .init(blockId: ls.b0.id, index: 0, distance: 30, direction: .next)))
    }

    func testOccupyBlockWithTwoFeedbacksAndZeroLengthTrain() throws {
        ls.loc.length = 0
        ls.train.wagonsLength = 0
        try ls.reserve(block: ls.b2, positions: .head(blockId: ls.b2.id, index: 1, distance: 50, direction: .next))

        ls.assert(ls.b2.trainInstance, .next, expectedParts: [1: .locomotive])
        XCTAssertEqual(ls.train.positions, TrainPositions(head: .init(blockId: ls.b2.id, index: 1, distance: 50, direction: .next),
                                                          tail: .init(blockId: ls.b2.id, index: 1, distance: 50, direction: .next)))
    }

    // b0[ ]> b1[ f1 ]> b2[ f2.1 f2.2 ]> <t23> b3<[ f3.2 f3.1 ]
    //                          <
    func testOccupyBackwardBlockWithTwoFeedbacksAndZeroLengthTrain() throws {
        ls.loc.length = 0
        ls.train.wagonsLength = 0
        ls.loc.directionForward = false
        try ls.reserve(block: ls.b2, positions: .head(blockId: ls.b2.id, index: 1, distance: 50, direction: .previous))

        ls.assert(ls.b2.trainInstance, .previous, expectedParts: [1: .locomotive])
        XCTAssertEqual(ls.train.positions, TrainPositions(head: .init(blockId: ls.b2.id, index: 1, distance: 50, direction: .previous),
                                                          tail: .init(blockId: ls.b2.id, index: 1, distance: 50, direction: .previous)))
    }

    // blocks:    b0[   ]> b1[   f0   ]>
    // indexes:       0        0    1
    // distances:    100      50   50
    // train:         >-------------    (length=120)
    func testOccupyBackwardNextTwoBlocks_Head() throws {
        ls.loc.length = 20
        ls.train.wagonsLength = 100
        ls.loc.directionForward = false
        try ls.reserve(block: ls.b0, positions: .head(blockId: ls.b0.id, index: 0, distance: 50, direction: .next))

        ls.assert(ls.b0.trainInstance, .next, expectedParts: [0: .locomotive])
        ls.assert(ls.b1.trainInstance, .next, expectedParts: [0: .wagon, 1: .wagon])
        
        XCTAssertEqual(ls.train.positions, TrainPositions(head: .init(blockId: ls.b0.id, index: 0, distance: 50, direction: .next),
                                                          tail: .init(blockId: ls.b1.id, index: 1, distance: 70, direction: .next)))
    }

    // blocks:    b0[   ]> b1[   f0   ]>
    // indexes:       0        0    1
    // distances:    100      50   50
    // train:         >-------------    (length=120)
    func testOccupyBackwardNextTwoBlocks_Tail() throws {
        ls.loc.length = 20
        ls.train.wagonsLength = 100
        ls.loc.directionForward = false
        try ls.reserve(block: ls.b1, positions: .tail(blockId: ls.b1.id, index: 1, distance: 70, direction: .next))

        ls.assert(ls.b0.trainInstance, .next, expectedParts: [0: .locomotive])
        ls.assert(ls.b1.trainInstance, .next, expectedParts: [0: .wagon, 1: .wagon])
        
        XCTAssertEqual(ls.train.positions, TrainPositions(head: .init(blockId: ls.b0.id, index: 0, distance: 50, direction: .next),
                                                          tail: .init(blockId: ls.b1.id, index: 1, distance: 70, direction: .next)))
    }

    // blocks:    b0[   ]> b1[   f0   ]>
    // indexes:       0        0    1
    // distances:    100      50   50
    // train:         -------------<    (length=120)
    func testOccupyBackwardPreviousTwoBlocks_Head() throws {
        ls.loc.length = 20
        ls.train.wagonsLength = 100
        ls.loc.directionForward = false
        try ls.reserve(block: ls.b1, positions: .head(blockId: ls.b1.id, index: 1, distance: 60, direction: .previous))

        ls.assert(ls.b1.trainInstance, .previous, expectedParts: [0: .wagon, 1: .locomotive])
        ls.assert(ls.b0.trainInstance, .previous, expectedParts: [0: .wagon])
        
        XCTAssertEqual(ls.train.positions, TrainPositions(head: .init(blockId: ls.b1.id, index: 1, distance: 60, direction: .previous),
                                                          tail: .init(blockId: ls.b0.id, index: 0, distance: 40, direction: .previous)))
    }

    // blocks:    b0[   ]> b1[   f0   ]>
    // indexes:       0        0    1
    // distances:    100      50   50
    // train:         -------------<    (length=120)
    func testOccupyBackwardPreviousTwoBlocks_Tail() throws {
        ls.loc.length = 20
        ls.train.wagonsLength = 100
        ls.loc.directionForward = false
        try ls.reserve(block: ls.b0, positions: .tail(blockId: ls.b0.id, index: 0, distance: 40, direction: .previous))

        ls.assert(ls.b1.trainInstance, .previous, expectedParts: [0: .wagon, 1: .locomotive])
        ls.assert(ls.b0.trainInstance, .previous, expectedParts: [0: .wagon])
        
        XCTAssertEqual(ls.train.positions, TrainPositions(head: .init(blockId: ls.b1.id, index: 1, distance: 60, direction: .previous),
                                                          tail: .init(blockId: ls.b0.id, index: 0, distance: 40, direction: .previous)))
    }

    // b0[ ]> b1[ f1 ]> b2[ f2.1 f2.2 ]> <t23> b3<[ f3.2 f3.1 ]
    //                        ------------------------------->
    func testOccupyTwoBlocks2() throws {
        ls.loc.length = 20
        ls.train.wagonsLength = 100
        ls.loc.directionForward = true
        try ls.reserve(block: ls.b3, positions: .head(blockId: ls.b3.id, index: 0, distance: 10, direction: .previous))

        ls.assert(ls.b3.trainInstance, .previous, expectedParts: [2: .wagon, 1: .wagon, 0: .locomotive]) // Note: b3 has its direction backwards!
        ls.assert(ls.b2.trainInstance, .next, expectedParts: [1: .wagon, 2: .wagon])

        XCTAssertEqual(ls.train.positions, TrainPositions(head: .init(blockId: ls.b3.id, index: 0, distance: 10, direction: .next),
                                                          tail: .init(blockId: ls.b2.id, index: 1, distance: 80, direction: .previous)))
    }
}
