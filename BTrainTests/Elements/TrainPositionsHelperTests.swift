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

final class TrainPositionsHelperTests: XCTestCase {
    // ┌─────────┐           ┌──────┐   ┌──────┐  ┌──────┐            ┌──────┐
    // │    A    │──▶  AB  ─▶│  B   │──▶│  C   │─▶│  D   │──▶  DE  ──▶│  E   │
    // └─────────┘           └──────┘   └──────┘  └──────┘            └──────┘
    //                 │                                       ▲
    //                 │    ┌──────┐   ┌──────┐  ┌──────┐      │
    //                 └───▶│  B2  │──▶│ !C2  │─▶│  D2  │──────┘
    //                      └──────┘   └──────┘  └──────┘
    func testAllActiveFeedbackPositionsInSingleBlock() throws {
        let doc = LayoutDocument(layout: LayoutPointToPoint().newLayout())
        let layout = doc.layout
        let train = layout.trains[0]
        train.locomotive!.length = 20
        train.wagonsLength = 0
        let blockB = layout.block(named: "B")

        try doc.layoutController.setupTrainToBlock(train, blockB.id, naturalDirectionInBlock: .next)
        XCTAssertEqual(train.occupied.blocks.count, 1)

        try assertFeedbacks(layout, train, feedbackCount: 0)

        layout.toggle(blockB.feedbacks[0])
        try assertFeedbacks(layout, train, feedbackCount: 1)

        layout.toggle(blockB.feedbacks[1])
        try assertFeedbacks(layout, train, feedbackCount: 2)
    }

    // ┌─────────┐           ┌──────┐   ┌──────┐  ┌──────┐            ┌──────┐
    // │    A    │──▶  AB  ─▶│  B   │──▶│  C   │─▶│  D   │──▶  DE  ──▶│  E   │
    // └─────────┘           └──────┘   └──────┘  └──────┘            └──────┘
    //                 │                                       ▲
    //                 │    ┌──────┐   ┌──────┐  ┌──────┐      │
    //                 └───▶│  B2  │──▶│ !C2  │─▶│  D2  │──────┘
    //                      └──────┘   └──────┘  └──────┘
    func testAllActiveFeedbackPositionsInMultipleBlock() throws {
        let doc = LayoutDocument(layout: LayoutPointToPoint().newLayout())
        let layout = doc.layout
        let train = layout.trains[0]
        let blockA = layout.block(named: "A")
        let blockB = layout.block(named: "B")
        let blockC = layout.block(named: "C")

        train.wagonsLength = blockB.length!

        try doc.layoutController.setupTrainToBlock(train, blockB.id, naturalDirectionInBlock: .next)
        XCTAssertEqual(train.occupied.blocks.count, 2)

        try assertFeedbacks(layout, train, feedbackCount: 0)

        layout.toggle(blockB.feedbacks[0])
        try assertFeedbacks(layout, train, feedbackCount: 1)

        layout.toggle(blockA.feedbacks[1])
        try assertFeedbacks(layout, train, feedbackCount: 2)

        // Activating a feedback in a block that is not occupied should not be taken into account
        layout.toggle(blockC.feedbacks[0])
        try assertFeedbacks(layout, train, feedbackCount: 2)
    }

    private func assertFeedbacks(_ layout: Layout, _ train: Train, feedbackCount: Int) throws {
        let feedbacks = try layout.allOccupiedBlocksActiveFeedbackPositions(train: train)
        XCTAssertEqual(feedbacks.count, feedbackCount)
    }

    // MARK: - Toggling -

    // ┌─────────┐           ┌──────┐   ┌──────┐  ┌──────┐            ┌──────┐
    // │    A    │──▶  AB  ─▶│  B   │──▶│  C   │─▶│  D   │──▶  DE  ──▶│  E   │
    // └─────────┘           └──────┘   └──────┘  └──────┘            └──────┘
    //                 │                                       ▲
    //                 │    ┌──────┐   ┌──────┐  ┌──────┐      │
    //                 └───▶│  B2  │──▶│ !C2  │─▶│  D2  │──────┘
    //                      └──────┘   └──────┘  └──────┘

    func testToggleDirection() throws {
        let doc = LayoutDocument(layout: LayoutPointToPoint().newLayout())
        let layout = doc.layout
        let train = layout.trains[0]
        let blockA = layout.block(named: "A")

        try doc.layoutController.setupTrainToBlock(train, blockA.id, naturalDirectionInBlock: .next)

        XCTAssertTrue(train.directionForward)
        XCTAssertEqual(train.positions, .both(blockId: blockA.id,
                                              headIndex: blockA.feedbacks.count,
                                              headDistance: blockA.feedbacks.last!.distance!.after,
                                              tailIndex: 1,
                                              tailDistance: (blockA.feedbacks.last!.distance! - train.length!).after,
                                              direction: .next))

        // Toggle > backward
        try doc.layoutController.toggleTrainDirection(train)

        XCTAssertFalse(train.directionForward)
        XCTAssertEqual(train.positions, .both(blockId: blockA.id,
                                              headIndex: blockA.feedbacks.count,
                                              headDistance: blockA.feedbacks.last!.distance!.after,
                                              tailIndex: 1,
                                              tailDistance: (blockA.feedbacks.last!.distance! - train.length!).after,
                                              direction: .previous))

        // Toggle > forward
        try doc.layoutController.toggleTrainDirection(train)

        XCTAssertTrue(train.directionForward)
        XCTAssertEqual(train.positions, .both(blockId: blockA.id,
                                              headIndex: blockA.feedbacks.count,
                                              headDistance: blockA.feedbacks.last!.distance!.after,
                                              tailIndex: 1,
                                              tailDistance: (blockA.feedbacks.last!.distance! - train.length!).after,
                                              direction: .next))
    }

    // MARK: - Setup Train

    // ┌─────────┐           ┌──────┐   ┌──────┐  ┌──────┐            ┌──────┐
    // │    A    │──▶  AB  ─▶│  B   │──▶│  C   │─▶│  D   │──▶  DE  ──▶│  E   │
    // └─────────┘           └──────┘   └──────┘  └──────┘            └──────┘
    //                 │                                       ▲
    //                 │    ┌──────┐   ┌──────┐  ┌──────┐      │
    //                 └───▶│  B2  │──▶│ !C2  │─▶│  D2  │──────┘
    //                      └──────┘   └──────┘  └──────┘

    struct PositionAsserter {
        let allowedDirection: Locomotive.AllowedDirection
        let directionForward: Bool
        let directionInBlock: Direction
        let positions: TrainPositions
    }

    private func assert(_ doc: LayoutDocument,
                        _ train: Train,
                        _ block: Block,
                        _ directionForward: Bool,
                        _ directionInBlock: Direction,
                        _ position: TrainPositions) throws
    {
        train.locomotive!.directionForward = directionForward
        try doc.layoutController.setupTrainToBlock(train, block.id, naturalDirectionInBlock: directionInBlock)
        XCTAssertEqual(train.positions, position)
        XCTAssertEqual(train.occupied.blocks.count, 1)
    }

    func testSetupTrain() throws {
        let doc = LayoutDocument(layout: LayoutPointToPoint().newLayout())
        let layout = doc.layout
        let train = layout.trains[0]
        let blockA = layout.block(named: "A")

        // A: [ f0 f1 ] (length 200)
        // Train: length 120

        // Allowed direction: .forward / .any
        // Direction forward: true / false
        // Direction in block: .next / .previous
        let lastIndex = blockA.feedbacks.count

        // Block: [ ---> ]
        // Train: ------->
        //               f
        try assert(doc, train, blockA, true, .next, .both(blockId: blockA.id,
                                                          headIndex: lastIndex,
                                                          headDistance: 180.after,
                                                          tailIndex: 1,
                                                          tailDistance: (180 - 120).after,
                                                          direction: .next))

        // Block: [ ---> ]
        // Train: <------
        //        f
        try assert(doc, train, blockA, true, .previous, .both(blockId: blockA.id,
                                                              headIndex: 0,
                                                              headDistance: 20.before,
                                                              tailIndex: lastIndex - 1,
                                                              tailDistance: (20 + 120).before,
                                                              direction: .previous))

        // Block: [ ---> ]
        // Train: -------<
        //        t      h
        try assert(doc, train, blockA, false, .previous, .both(blockId: blockA.id,
                                                               headIndex: lastIndex - 1,
                                                               headDistance: (20 + 120).before,
                                                               tailIndex: 0,
                                                               tailDistance: 20.before,
                                                               direction: .previous))
        // Block: [ ---> ]
        // Train: >-------
        //        h      t
        try assert(doc, train, blockA, false, .next, .both(blockId: blockA.id,
                                                           headIndex: 1,
                                                           headDistance: (180 - 120).after,
                                                           tailIndex: lastIndex,
                                                           tailDistance: 180.after,
                                                           direction: .next))
    }

    // MARK: -

    let f1 = Identifier<Feedback>(uuid: "f1")
    let f2 = Identifier<Feedback>(uuid: "f2")
    let f3 = Identifier<Feedback>(uuid: "f3")

    func testDistanceRemainingInBlock() {
        let block = Block(name: "b1")
        block.length = 100
        block.assign([f1, f2, f3])
        block.feedbacks[0].distance = 10
        block.feedbacks[1].distance = 50
        block.feedbacks[2].distance = 90

        let loc = Locomotive(name: "loc1")

        let t = Train(id: .init(uuid: "t1"), name: "SBB")
        t.locomotive = loc
        t.locomotive!.directionForward = true
        t.positions = .head(blockId: block.id, index: 0, distance: 0, direction: .next)
        block.trainInstance = .init(t.id, .next)

        // Block:    [ f1 f2 f3 ]>
        // Position:  0  1  2  3
        // Direction: ------>
        assertRemainingDistance(t, block: block, head: (block.id, 0, .next), tail: (block.id, 0, .next), distance: 90)
        assertRemainingDistance(t, block: block, head: (block.id, 1, .next), tail: (block.id, 0, .next), distance: 50)
        assertRemainingDistance(t, block: block, head: (block.id, 2, .next), tail: (block.id, 0, .next), distance: 10)
        assertRemainingDistance(t, block: block, head: (block.id, 3, .next), tail: (block.id, 0, .next), distance: 0)

        // Block:    [ f1 f2 f3 ]>
        // Position:  0  1  2  3
        // Direction:     <-----
        block.trainInstance = .init(t.id, .previous)
        assertRemainingDistance(t, block: block, head: (block.id, 3, .previous), tail: (block.id, 0, .previous), distance: 90)
        assertRemainingDistance(t, block: block, head: (block.id, 2, .previous), tail: (block.id, 0, .previous), distance: 50)
        assertRemainingDistance(t, block: block, head: (block.id, 1, .previous), tail: (block.id, 0, .previous), distance: 10)
        assertRemainingDistance(t, block: block, head: (block.id, 0, .previous), tail: (block.id, 0, .previous), distance: 0)
    }

    func testDistanceRemainingInBlockTravelingBackwards() {
        let block = Block(name: "b1")
        block.length = 100
        block.assign([f1, f2, f3])
        block.feedbacks[0].distance = 10
        block.feedbacks[1].distance = 50
        block.feedbacks[2].distance = 90

        let loc = Locomotive(name: "loc1")
        let t = Train(id: .init(uuid: "t1"), name: "SBB")
        t.locomotive = loc
        t.locomotive!.directionForward = false
        t.positions = .head(blockId: block.id, index: 0, distance: 0, direction: .next)
        block.trainInstance = .init(t.id, .next)

        // Block:    [ f1 f2 f3 ] >>>
        // Position:  0  1  2  3
        // Direction: >------
        assertRemainingDistance(t, block: block, head: (block.id, 0, .next), tail: (block.id, 0, .next), distance: 90)
        assertRemainingDistance(t, block: block, head: (block.id, 0, .next), tail: (block.id, 1, .next), distance: 50)
        assertRemainingDistance(t, block: block, head: (block.id, 0, .next), tail: (block.id, 2, .next), distance: 10)
        assertRemainingDistance(t, block: block, head: (block.id, 0, .next), tail: (block.id, 3, .next), distance: 0)

        block.trainInstance = .init(t.id, .previous)

        // Block:    [ f1 f2 f3 ]
        // Position:  0  1  2  3
        // Direction:     -----<
        assertRemainingDistance(t, block: block, head: (block.id, 0, .previous), tail: (block.id, 3, .previous), distance: 90)
        assertRemainingDistance(t, block: block, head: (block.id, 0, .previous), tail: (block.id, 2, .previous), distance: 50)
        assertRemainingDistance(t, block: block, head: (block.id, 0, .previous), tail: (block.id, 1, .previous), distance: 10)
        assertRemainingDistance(t, block: block, head: (block.id, 0, .previous), tail: (block.id, 0, .previous), distance: 0)
    }

    private func assertRemainingDistance(_ train: Train, block: Block, head: (Identifier<Block>, Int, Direction), tail: (Identifier<Block>, Int, Direction), distance: Double) {
        train.positions = .init(head: .init(blockId: head.0, index: head.1, distance: 0, direction: head.2), tail: .init(blockId: tail.0, index: tail.1, distance: 0, direction: tail.2))
        XCTAssertEqual(train.distanceLeftInFrontBlock(frontBlock: block), distance)
    }
}

private extension Layout {
    func toggle(_ feedback: Block.BlockFeedback) {
        feedbacks[feedback.feedbackId]!.detected.toggle()
    }
}
