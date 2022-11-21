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
        
        assert(layout, train, feedbackCount: 0)
        
        layout.toggle(blockB.feedbacks[0])
        assert(layout, train, feedbackCount: 1)

        layout.toggle(blockB.feedbacks[1])
        assert(layout, train, feedbackCount: 2)
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

        assert(layout, train, feedbackCount: 0)

        layout.toggle(blockB.feedbacks[0])
        assert(layout, train, feedbackCount: 1)

        layout.toggle(blockA.feedbacks[1])
        assert(layout, train, feedbackCount: 2)

        // Activating a feedback in a block that is not occupied should not be taken into account
        layout.toggle(blockC.feedbacks[0])
        assert(layout, train, feedbackCount: 2)
    }

    func testEndOfBlock() throws {
        let doc = LayoutDocument(layout: LayoutPointToPoint().newLayout())
        let layout = doc.layout
        let train = layout.trains[0]
        train.locomotive?.length = 20
        train.wagonsLength = 0
        let blockB = layout.block(named: "B")

        try doc.layoutController.setTrainToBlock(train, blockB.id, direction: .next)
        assertEndOfBlock(occupiedCount: 1, atEndOfBlock: true, block: blockB, train: train)

        try doc.layoutController.setTrainToBlock(train, blockB.id, position: TrainLocation(front: .init(block: 0, index: blockB.feedbacks.count+1), back: nil), direction: .next)
        assertEndOfBlock(occupiedCount: 1, atEndOfBlock: true, block: blockB, train: train)

        try doc.layoutController.setTrainToBlock(train, blockB.id, position: TrainLocation(front: .init(block: 0, index: blockB.feedbacks.count), back: nil), direction: .next)
        assertEndOfBlock(occupiedCount: 1, atEndOfBlock: false, block: blockB, train: train)

        train.locomotive!.directionForward = false
        
        try doc.layoutController.setTrainToBlock(train, blockB.id, position: TrainLocation(front: .init(block: 0, index: 0), back: .init(block: 0, index: blockB.feedbacks.count+1)), direction: .next)
        assertEndOfBlock(occupiedCount: 1, atEndOfBlock: true, block: blockB, train: train)

        try doc.layoutController.setTrainToBlock(train, blockB.id, position: TrainLocation(front: .init(block: 0, index: 0), back: .init(block: 0, index: blockB.feedbacks.count)), direction: .next)
        assertEndOfBlock(occupiedCount: 1, atEndOfBlock: false, block: blockB, train: train)
    }
    
    private func assertEndOfBlock(occupiedCount: Int, atEndOfBlock: Bool, block: Block, train: Train) {
        XCTAssertEqual(train.occupied.blocks.count, occupiedCount)
        XCTAssertEqual(try TrainLocationHelper.atEndOfBlock(block: block, train: train), atEndOfBlock)
    }
    
    private func assert(_ layout: Layout, _ train: Train, feedbackCount: Int) {
        let feedbacks = TrainLocationHelper.allActiveFeedbackPositions(train: train, layout: layout)
        XCTAssertEqual(feedbacks.count, feedbackCount)
    }
}

private extension Layout {
    
    func toggle(_ feedback: Block.BlockFeedback) {
        feedbacks[feedback.feedbackId]!.detected.toggle()
    }
}
