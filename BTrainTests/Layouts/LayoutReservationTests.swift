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

final class LayoutReservationTests: XCTestCase {
    func testRemoveLeadingBlocks() throws {
        let layout = LayoutComplex().newLayout()
        let train = layout.trains[0]

        let r = LayoutReservation(layout: layout, executor: nil, verbose: false)

        XCTAssertTrue(train.leading.items.isEmpty)

        r.removeLeadingReservation(train: train)
        XCTAssertTrue(train.leading.items.isEmpty)

        train.leading.append(layout.blocks[0])
        train.leading.append(layout.turnouts[0])
        train.leading.append(layout.transitions[0])

        XCTAssertEqual(train.leading.items.count, 3)

        r.removeLeadingReservation(train: train)
        XCTAssertTrue(train.leading.items.isEmpty)
    }

    // ┌─────────┐           ┌──────┐   ┌──────┐  ┌──────┐            ┌──────┐
    // │    A    │──▶  AB  ─▶│  B   │──▶│  C   │─▶│  D   │──▶  DE  ──▶│  E   │
    // └─────────┘           └──────┘   └──────┘  └──────┘            └──────┘
    //                 │                                       ▲
    //                 │    ┌──────┐   ┌──────┐  ┌──────┐      │
    //                 └───▶│  B2  │──▶│ !C2  │─▶│  D2  │──────┘
    //                      └──────┘   └──────┘  └──────┘
    func testUpdateReservedBlocks() throws {
        let layout = LayoutPointToPoint().newLayout()
        let r = LayoutReservation(layout: layout, executor: nil, verbose: false)

        let train = layout.trains[0]
        let blockA = layout.block(named: "A")
        let route = layout.route(named: "ABCDE")

        train.block = blockA
        train.positions = .both(blockId: blockA.id, headIndex: blockA.feedbacks.count, headDistance: blockA.feedbacks.last!.distance!.after, tailIndex: 0, tailDistance: 0.after)
        train.routeStepIndex = 0
        train.startRouteIndex = 0
        blockA.trainInstance = .init(train.id, .next)
        train.routeId = route.id

        XCTAssertTrue(train.occupied.items.isEmpty)
        XCTAssertTrue(train.leading.items.isEmpty)

        try route.completePartialSteps(layout: layout, train: train)
        XCTAssertEqual(route.steps.toStrings(layout), ["A:next", "B:next", "C:next", "D:next", "E:next"])

        XCTAssertEqual(try r.updateReservedBlocks(train: train), .success)

        XCTAssertEqual(train.occupied.items.count, 1)
        XCTAssertEqual(train.occupied.blocks.toBlockNames, ["A"])
        XCTAssertEqual(train.leading.items.count, 4)
        XCTAssertEqual(train.leading.blocks.toBlockNames, ["B"])

        XCTAssertEqual(try r.updateReservedBlocks(train: train), .successAndUnchanged)

        XCTAssertTrue(r.removeLeadingReservation(train: train))

        XCTAssertEqual(train.occupied.items.count, 1)
        XCTAssertTrue(train.leading.items.isEmpty)

        XCTAssertTrue(r.removeOccupation(train: train))

        XCTAssertTrue(train.occupied.items.isEmpty)
        XCTAssertTrue(train.leading.items.isEmpty)

        XCTAssertFalse(r.removeOccupation(train: train))

        XCTAssertNotNil(train.block?.trainInstance)

        train.occupied.append(train.block!)
        XCTAssertTrue(r.removeOccupation(train: train, removeFrontBlock: true))
        XCTAssertNil(train.block?.trainInstance)
    }
    
    // b0[ ]> b1[ f1 ]> b2[ f2.1 f2.2 ]> <t23> b3<[ f3.2 f3.1 ]
    struct LayoutSample {
        let layout: Layout
        
        let b0: Block
        let b1: Block
        let b2: Block
        let b3: Block

        let train: Train
        let loc: Locomotive
        
        internal init() {
            layout = Layout()

            b0 = Block(name: "b0")
            b0.length = 100
            layout.blocks.add(b0)

            b1 = Block(name: "b1")
            b1.length = 100
            b1.feedbacks.append(.init(id: "f1", feedbackId: .init(uuid: "f1"), distance: 50))
            layout.blocks.add(b1)

            b2 = Block(name: "b2")
            b2.length = 100
            b2.feedbacks.append(.init(id: "f2.1", feedbackId: .init(uuid: "f2.1"), distance: 20))
            b2.feedbacks.append(.init(id: "f2.2", feedbackId: .init(uuid: "f2.2"), distance: 80))
            layout.blocks.add(b2)

            b3 = Block(name: "b3")
            b3.length = 100
            b3.feedbacks.append(.init(id: "f3.1", feedbackId: .init(uuid: "f3.1"), distance: 30))
            b3.feedbacks.append(.init(id: "f3.2", feedbackId: .init(uuid: "f3.2"), distance: 70))
            layout.blocks.add(b3)

            let t23 = Turnout(name: "t23")
            t23.length = 10
            layout.turnouts.add(t23)
            
            layout.link(from: b0.next, to: b1.previous)
            layout.link(from: b1.next, to: b2.previous)
            layout.link(from: b2.next, to: t23.socket0)
            layout.link(from: t23.socket1, to: b3.next)
            
            loc = Locomotive()
            loc.length = 20
            train = Train()
            train.locomotive = loc
        }
        
        /// Reserve the necessary elements for the train at the specified positions and direction in the block
        /// - Parameters:
        ///   - block: the block in which the positions is defined (head or tail depending on the direction of travel and detection)
        ///   - positions: the positions
        ///   - direction: the direction in which the train travels within the block
        func reserve(block: Block, positions: TrainPositions, direction: Direction) throws {
            let r = LayoutReservation(layout: layout, executor: nil, verbose: false)
            
            loc.directionForward = true
            train.block = block
            block.trainInstance = .init(train.id, direction)
            
            train.positions = positions
            
            try r.occupyBlocksWith2(train: train)
        }
        
        func assert(_ ti: TrainInstance?, _ direction: Direction, expectedParts: [Int:TrainInstance.TrainPart]) {
            XCTAssertEqual(ti?.trainId, train.id)
            XCTAssertEqual(ti?.direction, direction)
            XCTAssertEqual(ti?.parts, expectedParts, "Mismatching parts")
        }
        
    }
    
    let ls = LayoutSample()
    
    // blocks:    b0[   ]>
    // indexes:       0
    // distances:    100
    // train:        -->    (length=20)
    func testOccupySingleBlockNext() throws {
        try ls.reserve(block: ls.b0, positions: .head(blockId: ls.b0.id, index: 0, distance: 50), direction: .next)
        ls.assert(ls.b0.trainInstance, .next, expectedParts: [0: .locomotive])
        XCTAssertEqual(ls.train.positions, .both(blockId: ls.b0.id, headIndex: 0, headDistance: 50, tailIndex: 0, tailDistance: 30))
    }

    func testOccupySingleBlockNextWithZeroLengthTrain() throws {
        ls.loc.length = 0
        ls.train.wagonsLength = 0
        try ls.reserve(block: ls.b0, positions: .head(blockId: ls.b0.id, index: 0, distance: 50), direction: .next)
        ls.assert(ls.b0.trainInstance, .next, expectedParts: [0: .locomotive])
        XCTAssertEqual(ls.train.positions, .both(blockId: ls.b0.id, headIndex: 0, headDistance: 50, tailIndex: 0, tailDistance: 50))
    }

    // blocks:    b0[   ]>
    // indexes:       0
    // distances:    100
    // train:         <--    (length=20)
    func testOccupySingleBlockPrevious() throws {
        try ls.reserve(block: ls.b0, positions: .head(blockId: ls.b0.id, index: 0, distance: 50), direction: .previous)
        ls.assert(ls.b0.trainInstance, .previous, expectedParts: [0: .locomotive])
        XCTAssertEqual(ls.train.positions, .both(blockId: ls.b0.id, headIndex: 0, headDistance: 50, tailIndex: 0, tailDistance: 70))
    }

    // blocks:    b0[   ]> b1[   f0   ]>
    // indexes:       0        0    1
    // distances:    100      50   50
    // train:         ------------->    (length=120)
    func testOccupyTwoBlocksNext() throws {
        ls.loc.length = 20
        ls.train.wagonsLength = 100
        try ls.reserve(block: ls.b1, positions: .head(blockId: ls.b1.id, index: 1, distance: 50), direction: .next)

        ls.assert(ls.b0.trainInstance, .next, expectedParts: [0: .wagon])
        ls.assert(ls.b1.trainInstance, .next, expectedParts: [0: .locomotive])
        XCTAssertEqual(ls.train.positions, TrainPositions(head: .init(blockId: ls.b1.id, index: 1, distance: 50),
                                                          tail: .init(blockId: ls.b0.id, index: 0, distance: 30)))
    }

    func testOccupyBlockWithTwoFeedbacksAndZeroLengthTrain() throws {
        ls.loc.length = 0
        ls.train.wagonsLength = 0
        try ls.reserve(block: ls.b2, positions: .head(blockId: ls.b2.id, index: 1, distance: 50), direction: .next)

        ls.assert(ls.b2.trainInstance, .next, expectedParts: [1: .locomotive])
        XCTAssertEqual(ls.train.positions, TrainPositions(head: .init(blockId: ls.b2.id, index: 1, distance: 50),
                                                          tail: .init(blockId: ls.b2.id, index: 1, distance: 50)))
    }

    func testOccupyBlockBackwardsWithTwoFeedbacksAndZeroLengthTrain() throws {
        ls.loc.length = 0
        ls.train.wagonsLength = 0
        ls.loc.directionForward = false
        try ls.reserve(block: ls.b2, positions: .head(blockId: ls.b2.id, index: 1, distance: 50), direction: .previous)

        ls.assert(ls.b2.trainInstance, .previous, expectedParts: [1: .locomotive])
        XCTAssertEqual(ls.train.positions, TrainPositions(head: .init(blockId: ls.b2.id, index: 1, distance: 50),
                                                          tail: .init(blockId: ls.b2.id, index: 1, distance: 50)))
    }

    // blocks:    b0[   ]> b1[   f0   ]>
    // indexes:       0        0    1
    // distances:    100      50   50
    // train:         >-------------    (length=120)
    func testOccupyTwoBlocks() throws {
        ls.loc.length = 20
        ls.train.wagonsLength = 100
        ls.loc.directionForward = false
        try ls.reserve(block: ls.b0, positions: .head(blockId: ls.b0.id, index: 0, distance: 50), direction: .previous)

        ls.assert(ls.b0.trainInstance, .previous, expectedParts: [0: .locomotive])
        ls.assert(ls.b1.trainInstance, .previous, expectedParts: [0: .wagon, 1: .wagon])
        
        XCTAssertEqual(ls.train.positions, TrainPositions(head: .init(blockId: ls.b0.id, index: 0, distance: 50),
                                                          tail: .init(blockId: ls.b1.id, index: 1, distance: 70)))
    }

    // b0[ ]> b1[ f1 ]> b2[ f2.1 f2.2 ]> <t23> b3<[ f3.2 f3.1 ]
    //                        ------------------------------->
    func testOccupyTwoBlocks2() throws {
        ls.loc.length = 20
        ls.train.wagonsLength = 100
        ls.loc.directionForward = true
        try ls.reserve(block: ls.b3, positions: .head(blockId: ls.b3.id, index: 0, distance: 10), direction: .previous)

        ls.assert(ls.b3.trainInstance, .previous, expectedParts: [2: .wagon, 1: .wagon, 0: .locomotive]) // Note: b3 has its direction backwards!
        ls.assert(ls.b2.trainInstance, .next, expectedParts: [1: .wagon, 2: .wagon])

        XCTAssertEqual(ls.train.positions, TrainPositions(head: .init(blockId: ls.b3.id, index: 0, distance: 10),
                                                          tail: .init(blockId: ls.b2.id, index: 1, distance: 80)))
    }
}
