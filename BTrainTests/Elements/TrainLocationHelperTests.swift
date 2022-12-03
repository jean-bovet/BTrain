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

        try doc.layoutController.setupTrainToBlock(train, blockB.id, naturalDirectionInBlock: .next)
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
        
        try doc.layoutController.setupTrainToBlock(train, blockB.id, naturalDirectionInBlock: .next)
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
        let feedbacks = layout.allActiveFeedbackPositions(train: train)
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
        XCTAssertEqual(train.position, .both(blockId: blockA.id,
                                             frontIndex: blockA.feedbacks.count,
                                             frontDistance: blockA.feedbacks.last!.distance!+distanceDelta,
                                             backIndex: 1,
                                             backDistance: blockA.feedbacks.last!.distance!-train.length!+distanceDelta))
        
        // Toggle > backward
        train.locomotive?.directionForward.toggle()
        try doc.layoutController.toggleTrainDirection(train)
        
        XCTAssertFalse(train.directionForward)
        XCTAssertEqual(train.position, .both(blockId: blockA.id,
                                             frontIndex: blockA.feedbacks.count,
                                             frontDistance: blockA.feedbacks.last!.distance!+distanceDelta,
                                             backIndex: 1,
                                             backDistance: blockA.feedbacks.last!.distance!-train.length!+distanceDelta))

        // Toggle > forward
        train.locomotive?.directionForward.toggle()
        try doc.layoutController.toggleTrainDirection(train)

        XCTAssertTrue(train.directionForward)
        XCTAssertEqual(train.position, .both(blockId: blockA.id,
                                             frontIndex: blockA.feedbacks.count,
                                             frontDistance: blockA.feedbacks.last!.distance!+distanceDelta,
                                             backIndex: 1,
                                             backDistance: blockA.feedbacks.last!.distance!-train.length!+distanceDelta))
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
        let position: TrainLocation
    }
    
    private func assert(_ doc: LayoutDocument,
                                _ train: Train,
                                _ block: Block,
                                _ directionForward: Bool,
                                _ directionInBlock: Direction,
                                _ position: TrainLocation) throws {
        train.locomotive?.directionForward = directionForward
        try doc.layoutController.setupTrainToBlock(train, block.id, naturalDirectionInBlock: directionInBlock)
        XCTAssertEqual(train.position, position)
        XCTAssertEqual(train.occupied.blocks.count, 1)
    }
    
    func testSetupTrainToBlockAndChangeDirection() throws {
        let doc = LayoutDocument(layout: LayoutPointToPoint().newLayout())
        let layout = doc.layout
        let train = layout.trains[0]
        let blockA = layout.block(named: "A")
        
        // A: [ f0 f1 ] (length 200)
        // B: [ f0 f1 ] (length 100)
        // Train: length 120
        
        // Allowed direction: .forward / .any
        // Direction forward: true / false
        // Direction in block: .next / .previous
        let lastIndex = blockA.feedbacks.count
        
        // Block: [ ---> ]
        // Train: ------->
        //               f
        try assert(doc, train, blockA, true, .next, .both(blockId: blockA.id,
                                                          frontIndex: lastIndex,
                                                          frontDistance: 180+distanceDelta,
                                                          backIndex: 1,
                                                          backDistance: 180-120+distanceDelta))
        
        // Block: [ ---> ]
        // Train: <------
        //        f
        try assert(doc, train, blockA, true, .previous, .both(blockId: blockA.id,
                                                              frontIndex: 0,
                                                              frontDistance: 20-distanceDelta,
                                                              backIndex: lastIndex-1,
                                                              backDistance: 20+120-distanceDelta))
                
        // Block: [ ---> ]
        // Train: -------<
        //        b      f
        // Note: the train is setup first with its directionForward=true, and then it is toggled
        try assert(doc, train, blockA, false, .next, .both(blockId: blockA.id,
                                                           frontIndex: lastIndex,
                                                           frontDistance: 180+distanceDelta,
                                                           backIndex: 1,
                                                           backDistance: 180-120+distanceDelta))
        // Block: [ ---> ]
        // Train: >-------
        //        f      b
        // Note: the train is setup first with its directionForward=true, and then it is toggled
        try assert(doc, train, blockA, false, .previous, .both(blockId: blockA.id,
                                                               frontIndex: 0,
                                                               frontDistance: 20-distanceDelta,
                                                               backIndex: lastIndex-1,
                                                               backDistance: 20+120-distanceDelta))
    }
    
    // MARK: - End of Block
    
    func testEndOfBlock() throws {
        let doc = LayoutDocument(layout: LayoutPointToPoint().newLayout())
        let layout = doc.layout
        let train = layout.trains[0]
        train.locomotive?.length = 20
        train.wagonsLength = 0
        // Block B (length=100): [ b.1  b.2  ]>
        // Positions:             0   1    2
        // Feedbacks:              20   80
        let blockB = layout.block(named: "B")

        try doc.layoutController.setupTrainToBlock(train, blockB.id, naturalDirectionInBlock: .next)
        assertEndOfBlock(occupiedCount: 1, atEndOfBlock: true, block: blockB, train: train)

        try doc.layout.setTrainToBlock(train, blockB.id, position: TrainLocation(front: .init(blockId: blockB.id, index: blockB.feedbacks.count, distance: 0), back: nil), directionOfTravelInBlock: .next)
        assertEndOfBlock(occupiedCount: 1, atEndOfBlock: true, block: blockB, train: train)

        try doc.layout.setTrainToBlock(train, blockB.id, position: TrainLocation(front: .init(blockId: blockB.id, index: blockB.feedbacks.count-1, distance: 0), back: nil), directionOfTravelInBlock: .next)
        assertEndOfBlock(occupiedCount: 1, atEndOfBlock: false, block: blockB, train: train)

        train.locomotive!.directionForward = false
  
        // Not at the end of the block because the train is too short and spans only position 2 and 1 (because the train
        // is setup first as moving forward before being toggle backward).
        try doc.layoutController.setupTrainToBlock(train, blockB.id, naturalDirectionInBlock: .next)
        assertEndOfBlock(occupiedCount: 1, atEndOfBlock: false, block: blockB, train: train)

        try doc.layout.setTrainToBlock(train, blockB.id, position: .both(blockId: blockB.id, frontIndex: blockB.feedbacks.count, frontDistance: 0, backIndex: 1, backDistance: 0), directionOfTravelInBlock: .next)
        assertEndOfBlock(occupiedCount: 1, atEndOfBlock: false, block: blockB, train: train)
        
        // Now let's set a longer length to the train so it fills the entire block
        train.wagonsLength = 60
        try doc.layoutController.setupTrainToBlock(train, blockB.id, naturalDirectionInBlock: .next)
        assertEndOfBlock(occupiedCount: 1, atEndOfBlock: true, block: blockB, train: train)
    }
    
    private func assertEndOfBlock(occupiedCount: Int, atEndOfBlock: Bool, block: Block, train: Train) {
        XCTAssertEqual(train.occupied.blocks.count, occupiedCount)
        XCTAssertEqual(try train.atEndOfBlock(block: block), atEndOfBlock)
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
        assertRemainingDistance(t, front: (block.id,0), back: (block.id,0), distance: 90)
        assertRemainingDistance(t, front: (block.id,1), back: (block.id,0), distance: 50)
        assertRemainingDistance(t, front: (block.id,2), back: (block.id,0), distance: 10)
        assertRemainingDistance(t, front: (block.id,3), back: (block.id,0), distance: 0)
        
        // Block:    [ f1 f2 f3 ]
        // Position:  0  1  2  3
        // Direction:     <-----
        block.trainInstance = .init(t.id, .previous)
        assertRemainingDistance(t, front: (block.id,3), back: (block.id,0), distance: 90)
        assertRemainingDistance(t, front: (block.id,2), back: (block.id,0), distance: 50)
        assertRemainingDistance(t, front: (block.id,1), back: (block.id,0), distance: 10)
        assertRemainingDistance(t, front: (block.id,0), back: (block.id,0), distance: 0)
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
        assertRemainingDistance(t, front: (block.id,0), back: (block.id,0), distance: 90)
        assertRemainingDistance(t, front: (block.id,0), back: (block.id,1), distance: 50)
        assertRemainingDistance(t, front: (block.id,0), back: (block.id,2), distance: 10)
        assertRemainingDistance(t, front: (block.id,0), back: (block.id,3), distance: 0)

        block.trainInstance = .init(t.id, .previous)

        // Block:    [ f1 f2 f3 ]
        // Position:  0  1  2  3
        // Direction:     -----<
        assertRemainingDistance(t, front: (block.id,0), back: (block.id,3), distance: 90)
        assertRemainingDistance(t, front: (block.id,0), back: (block.id,2), distance: 50)
        assertRemainingDistance(t, front: (block.id,0), back: (block.id,1), distance: 10)
        assertRemainingDistance(t, front: (block.id,0), back: (block.id,0), distance: 0)
    }

    private func assertRemainingDistance(_ train: Train, front: (Identifier<Block>, Int), back: (Identifier<Block>, Int), distance: Double) {
        train.position = .init(front:.init(blockId: front.0, index: front.1, distance: 0), back:.init(blockId: back.0, index: back.1, distance: 0))
        XCTAssertEqual(train.distanceLeftInLastBlock(), distance)
    }
    
}

private extension Layout {
    
    func toggle(_ feedback: Block.BlockFeedback) {
        feedbacks[feedback.feedbackId]!.detected.toggle()
    }
}
