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

class ManualOperationTests: BTTestCase {

    // b1 > b2 > b1
    func testFollowManualOperation() throws {
        let layout = LayoutACreator().newLayout()
        let p = try setup(layout: layout, fromBlockId: "b1")
        
        p.setTrainSpeed(100)
        
        try p.assertTrain(inBlock: "b1", position: 0, speed: 100)

        try p.triggerFeedback("f21")
        
        try p.assertTrain(notInBlock: "b1")
        try p.assertTrain(inBlock: "b2", position: 1, speed: 100)
        
        try p.triggerFeedback("f21", false)
        try p.triggerFeedback("f22")
        
        try p.assertTrain(notInBlock: "b1")
        try p.assertTrain(inBlock: "b2", position: 2, speed: 100)
        
        try p.triggerFeedback("f22", false)
        try p.triggerFeedback("f11")
        
        try p.assertTrain(notInBlock: "b2")
        try p.assertTrain(inBlock: "b1", position: 1, speed: 100)

        // Put another train in b2 and ensure the train is stopped when
        // it reaches the end of b1 as a protection mechanism
        layout.blocks[1].reserved = .init("anotherTrain", .next)
        
        try p.triggerFeedback("f11", false)
        try p.triggerFeedback("f12")
        
        try p.assertTrain(notInBlock: "b2")
        try p.assertTrain(inBlock: "b1", position: 2, speed: 0)
    }

    // b1 > b2 > b3 > !b1
    func testPullingLongTrain() throws {
        let layout = LayoutACreator().newLayout()
        
        layout.turnouts[1].state = .branchLeft
        
        let b1 = layout.blocks[0]
        let b2 = layout.blocks[1]
        let b3 = layout.blocks[2]

        b1.length = 100
        b1.feedbacks[0].distance = 20
        b1.feedbacks[1].distance = 80
        
        b2.length = 20
        b2.feedbacks[0].distance = 5
        b2.feedbacks[1].distance = 15
        
        b3.length = 20
        b3.feedbacks[0].distance = 5
        b3.feedbacks[1].distance = 15

        let train = layout.trains[0]
        train.length = 60
        
//        try layout.setLocomotiveDirection(train, forward: false)
//        train.wagonsPushedByLocomotive = true
        
        let p = try setup(layout: layout, fromBlockId: "b1")
        
        p.setTrainSpeed(100)

        try p.assertTrain(inBlock: "b1", position: 0, speed: 100)

        try p.triggerFeedback("f21")
        
        try p.assertTrain(inBlock: "b1", position: 1, speed: 100)
        try p.assertTrain(inBlock: "b2", position: 1, speed: 100)
        
        try p.triggerFeedback("f21", false)
        try p.triggerFeedback("f22")
        
        try p.assertTrain(inBlock: "b1", position: 2, speed: 100)
        try p.assertTrain(inBlock: "b2", position: 2, speed: 100)
        
        try p.triggerFeedback("f22", false)
        try p.triggerFeedback("f31")
        
        try p.assertTrain(inBlock: "b1", position: 1, speed: 100)
        try p.assertTrain(inBlock: "b2", position: 1, speed: 100)
        try p.assertTrain(inBlock: "b3", position: 1, speed: 100)
        
        try p.triggerFeedback("f31", false)
        try p.triggerFeedback("f32")
        
        // Train stops because its tail is still in the block b1
        try p.assertTrain(inBlock: "b1", position: 2, speed: 0)
        try p.assertTrain(inBlock: "b2", position: 2, speed: 0)
        try p.assertTrain(inBlock: "b3", position: 2, speed: 0)
    }
    
    // b1 > b2 > b3 > !b1
    func testPushingLongTrain() throws {
        let layout = LayoutACreator().newLayout()
        
        layout.turnouts[1].state = .branchLeft
        
        let b1 = layout.blocks[0]
        let b2 = layout.blocks[1]
        let b3 = layout.blocks[2]

        b1.length = 100
        b1.feedbacks[0].distance = 20
        b1.feedbacks[1].distance = 80
        
        b2.length = 20
        b2.feedbacks[0].distance = 5
        b2.feedbacks[1].distance = 15
        
        b3.length = 20
        b3.feedbacks[0].distance = 5
        b3.feedbacks[1].distance = 15

        let train = layout.trains[0]
        train.length = 60
        
        layout.setLocomotiveDirection(train, forward: false)
        train.wagonsPushedByLocomotive = true
        
        let p = try setup(layout: layout, fromBlockId: "b1")
        
        p.setTrainSpeed(100)

        try p.assertTrain(inBlock: "b1", position: 0, speed: 100)
        try p.assertTrain(notInBlock: "b2")
        try p.assertTrain(notInBlock: "b3")

        var headWagonBlock = try TrainPositionFinder.headWagonBlockFor(train: train, layout: layout)!
        XCTAssertEqual(headWagonBlock.id, b1.id)

        // The train advances within b1
        try p.triggerFeedback("f11")
        
        headWagonBlock = try TrainPositionFinder.headWagonBlockFor(train: train, layout: layout)!
        XCTAssertEqual(headWagonBlock.id, b3.id)

        // The train should stop because it is occupying all the blocks and will hit
        // itself back in b1 if it continues.
        try p.assertTrain(inBlock: "b1", position: 1, speed: 0)
        try p.assertTrain(inBlock: "b2", position: 1, speed: 0)
        try p.assertTrain(inBlock: "b3", position: 1, speed: 0)
    }
    
    // MARK: -- Utility
    
    // Convenience structure to test the layout and its route
    private struct Package {
        let layout: Layout
        let train: Train
        let asserter: LayoutAsserter
        let layoutController: LayoutController

        func assertTrain(inBlock named: String, position: Int, speed: TrainSpeed.UnitKph) throws {
            let blockId = Identifier<Block>(uuid: named)
            guard let block = layout.block(for: blockId) else {
                throw LayoutError.blockNotFound(blockId: blockId)
            }
            
            XCTAssertEqual(block.train?.trainId, train.id)
            XCTAssertEqual(train.position, position)
            XCTAssertEqual(train.speed.requestedKph, speed)
        }
        
        func assertTrain(notInBlock named: String) throws {
            let blockId = Identifier<Block>(uuid: named)
            guard let block = layout.block(for: blockId) else {
                throw LayoutError.blockNotFound(blockId: blockId)
            }

            XCTAssertNil(block.train)
        }
        
        func setTrainSpeed(_ speed: TrainSpeed.UnitKph) {
            layout.setTrainSpeed(train, speed) { }
            _ = layoutController.run()
        }
                
        func triggerFeedback(_ named: String, _ detected: Bool = true) throws {
            let feedbackId = Identifier<Feedback>(uuid: named)
            guard let feedback = layout.feedback(for: feedbackId) else {
                throw LayoutError.feedbackNotFound(feedbackId: feedbackId)
            }

            feedback.detected = detected
            _ = layoutController.run()
        }
    }
    
    private func setup(layout: Layout, fromBlockId: String, position: Position = .start, direction: Direction = .next) throws -> Package {
        layout.detectUnexpectedFeedback = true
        layout.strictRouteFeedbackStrategy = true

        let train = layout.trains[0]
        try layout.setTrainToBlock(train.id, Identifier<Block>(uuid: fromBlockId), position: position, direction: direction)
        
        XCTAssertEqual(train.speed.requestedKph, 0)
        XCTAssertTrue(train.manualScheduling)
        XCTAssertEqual(train.state, .stopped)

        let layoutController = LayoutController(layout: layout, switchboard: nil, interface: MarklinInterface())
        let asserter = LayoutAsserter(layout: layout, layoutController: layoutController)
        return Package(layout: layout, train: train, asserter: asserter, layoutController: layoutController)
    }

}
