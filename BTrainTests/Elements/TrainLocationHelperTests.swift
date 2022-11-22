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

final class TrainLocationHelperTests: XCTestCase {

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
        train.locomotive?.length = 20
        train.wagonsLength = 0
        let blockB = layout.block(named: "B")

        try doc.layoutController.setTrainToBlock(train, blockB.id, direction: .next)
        XCTAssertEqual(train.occupied.blocks.count, 1)
        
        assertFeedbacks(layout, train, feedbackCount: 0)
        
        layout.toggle(blockB.feedbacks[0])
        assertFeedbacks(layout, train, feedbackCount: 1)

        layout.toggle(blockB.feedbacks[1])
        assertFeedbacks(layout, train, feedbackCount: 2)
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
        
        try doc.layoutController.setTrainToBlock(train, blockB.id, direction: .next)
        XCTAssertEqual(train.occupied.blocks.count, 2)

        assertFeedbacks(layout, train, feedbackCount: 0)

        layout.toggle(blockB.feedbacks[0])
        assertFeedbacks(layout, train, feedbackCount: 1)

        layout.toggle(blockA.feedbacks[1])
        assertFeedbacks(layout, train, feedbackCount: 2)

        // Activating a feedback in a block that is not occupied should not be taken into account
        layout.toggle(blockC.feedbacks[0])
        assertFeedbacks(layout, train, feedbackCount: 2)
    }

    private func assertFeedbacks(_ layout: Layout, _ train: Train, feedbackCount: Int) {
        let feedbacks = TrainLocationHelper.allActiveFeedbackPositions(train: train, layout: layout)
        XCTAssertEqual(feedbacks.count, feedbackCount)
    }

    // MARK: -
    
    func testEndOfBlock() throws {
        let doc = LayoutDocument(layout: LayoutPointToPoint().newLayout())
        let layout = doc.layout
        let train = layout.trains[0]
        train.locomotive?.length = 20
        train.wagonsLength = 0
        let blockB = layout.block(named: "B")

        try doc.layoutController.setTrainToBlock(train, blockB.id, direction: .next)
        assertEndOfBlock(occupiedCount: 1, atEndOfBlock: true, block: blockB, train: train)

        try doc.layoutController.setTrainToBlock(train, blockB.id, position: TrainLocation(front: .init(blockIndex: 0, index: blockB.feedbacks.count+1), back: nil), direction: .next)
        assertEndOfBlock(occupiedCount: 1, atEndOfBlock: true, block: blockB, train: train)

        try doc.layoutController.setTrainToBlock(train, blockB.id, position: TrainLocation(front: .init(blockIndex: 0, index: blockB.feedbacks.count), back: nil), direction: .next)
        assertEndOfBlock(occupiedCount: 1, atEndOfBlock: false, block: blockB, train: train)

        train.locomotive!.directionForward = false
        
        try doc.layoutController.setTrainToBlock(train, blockB.id, position: TrainLocation(front: .init(blockIndex: 0, index: 0), back: .init(blockIndex: 0, index: blockB.feedbacks.count+1)), direction: .next)
        assertEndOfBlock(occupiedCount: 1, atEndOfBlock: true, block: blockB, train: train)

        try doc.layoutController.setTrainToBlock(train, blockB.id, position: TrainLocation(front: .init(blockIndex: 0, index: 0), back: .init(blockIndex: 0, index: blockB.feedbacks.count)), direction: .next)
        assertEndOfBlock(occupiedCount: 1, atEndOfBlock: false, block: blockB, train: train)
    }
    
    private func assertEndOfBlock(occupiedCount: Int, atEndOfBlock: Bool, block: Block, train: Train) {
        XCTAssertEqual(train.occupied.blocks.count, occupiedCount)
        XCTAssertEqual(try TrainLocationHelper.atEndOfBlock(block: block, train: train), atEndOfBlock)
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

        let t = Train(id: .init(uuid: "t1"), name: "SBB")
        t.locomotive = Locomotive(name: "loc1")
        t.locomotive?.directionForward = true
        
        block.trainInstance = .init(t.id, .next)
        t.occupied.append(block)
        
        // Block:    [ f1 f2 f3 ]
        // Position:  0  1  2  3
        // Direction: ------>
        assertRemainingDistance(t, front: (0,0), back: (0,0), distance: 90)
        assertRemainingDistance(t, front: (0,1), back: (0,0), distance: 50)
        assertRemainingDistance(t, front: (0,2), back: (0,0), distance: 10)
        assertRemainingDistance(t, front: (0,3), back: (0,0), distance: 0)
        
        // Block:    [ f1 f2 f3 ]
        // Position:  0  1  2  3
        // Direction:     <-----
        block.trainInstance = .init(t.id, .previous)
        assertRemainingDistance(t, front: (0,3), back: (0,0), distance: 90)
        assertRemainingDistance(t, front: (0,2), back: (0,0), distance: 50)
        assertRemainingDistance(t, front: (0,1), back: (0,0), distance: 10)
        assertRemainingDistance(t, front: (0,0), back: (0,0), distance: 0)
    }
    
    func testDistanceRemainingInBlockTravelingBackwards() {
        let block = Block(name: "b1")
        block.length = 100
        block.assign([f1, f2, f3])
        block.feedbacks[0].distance = 10
        block.feedbacks[1].distance = 50
        block.feedbacks[2].distance = 90

        let t = Train(id: .init(uuid: "t1"), name: "SBB")
        t.locomotive = Locomotive(name: "loc1")
        t.locomotive?.directionForward = false
        
        block.trainInstance = .init(t.id, .next)
        t.occupied.append(block)

        // Block:    [ f1 f2 f3 ] >>>
        // Position:  0  1  2  3
        // Direction: >------
        assertRemainingDistance(t, front: (0,0), back: (0,0), distance: 90)
        assertRemainingDistance(t, front: (0,0), back: (0,1), distance: 50)
        assertRemainingDistance(t, front: (0,0), back: (0,2), distance: 10)
        assertRemainingDistance(t, front: (0,0), back: (0,3), distance: 0)

        block.trainInstance = .init(t.id, .previous)

        // Block:    [ f1 f2 f3 ]
        // Position:  0  1  2  3
        // Direction:     -----<
        assertRemainingDistance(t, front: (0,0), back: (0,3), distance: 90)
        assertRemainingDistance(t, front: (0,0), back: (0,2), distance: 50)
        assertRemainingDistance(t, front: (0,0), back: (0,1), distance: 10)
        assertRemainingDistance(t, front: (0,0), back: (0,0), distance: 0)
    }

    private func assertRemainingDistance(_ train: Train, front: (Int, Int), back: (Int, Int), distance: Double) {
        train.position = .init(front:.init(blockIndex: front.0, index: front.1), back:.init(blockIndex: back.0, index: back.1))
        XCTAssertEqual(TrainLocationHelper.distanceLeftInLastBlock(train: train), distance)
    }
    
}

private extension Layout {
    
    func toggle(_ feedback: Block.BlockFeedback) {
        feedbacks[feedback.feedbackId]!.detected.toggle()
    }
}
