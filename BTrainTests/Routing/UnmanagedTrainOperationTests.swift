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

class UnmanagedTrainOperationTests: BTTestCase {

    // b1 > b2 > b1
    func testFollowManualOperation() throws {
        let layout = LayoutLoop1().newLayout()
        let p = try setup(layout: layout, fromBlockId: "b1")
        
        connectToSimulator(doc: p.doc)
        defer {
            disconnectFromSimulator(doc: p.doc)
        }
        
        p.setTrainSpeed(LayoutFactory.DefaultMaximumSpeed)
                
        try p.assertTrain(inBlock: "b1", position: 0, speed: LayoutFactory.DefaultMaximumSpeed)

        try p.triggerFeedback("f21")
        
        try p.assertTrain(notInBlock: "b1")
        try p.assertTrain(inBlock: "b2", position: 1, speed: LayoutFactory.DefaultMaximumSpeed)
                
        try p.triggerFeedback("f21", false)
        try p.triggerFeedback("f22")

        try p.assertTrain(notInBlock: "b1")
        try p.assertTrain(inBlock: "b2", position: 2, speed: LayoutFactory.DefaultMaximumSpeed)

        try p.triggerFeedback("f22", false)
        try p.triggerFeedback("f11")

        try p.assertTrain(notInBlock: "b2")
        try p.assertTrain(inBlock: "b1", position: 1, speed: LayoutFactory.DefaultMaximumSpeed)

        // Put another train in b2 and ensure the train is stopped when
        // it reaches the end of b1 as a protection mechanism
        // TODO: semi-automatic mode
//        layout.blocks[1].reserved = .init("anotherTrain", .next)

        try p.triggerFeedback("f11", false)
        try p.triggerFeedback("f12")

        p.doc.layoutController.waitUntilSettled()

        try p.assertTrain(notInBlock: "b2")
        try p.assertTrain(inBlock: "b1", position: 2, speed: LayoutFactory.DefaultMaximumSpeed)
    }

    //                 ┌─────────┐
    //┌────────────────│ Block 2 │◀────────────────────┐
    //│                └─────────┘                     │
    //│                                                │
    //│                                                │
    //│                ┌─────────┐
    //│       ┌───────▶│ Block 3 │────────────────▶Turnout12
    //│       │        └─────────┘
    //│       │                                        ▲
    //│       │                                        │
    //│                                 ┌─────────┐    │
    //└─▶Turnout21 ────────────────────▶│ Block 1 │────┘
    //                                  └─────────┘
    // b1 > b2 > b3 > !b1
    // TODO: semi-automatic mode
    func disabled_testPullingLongTrain() throws {
        let layout = LayoutLoop1().newLayout()
        
        layout.turnouts[1].setState(.branchLeft)
        
        layout.turnouts.forEach { $0.length = nil }
        
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
        train.locomotiveLength = 20
        train.wagonsLength = 40
                
        let p = try setup(layout: layout, fromBlockId: "b1", position: .end)
        
        connectToSimulator(doc: p.doc)
        defer {
            disconnectFromSimulator(doc: p.doc)
        }

        p.setTrainSpeed(LayoutFactory.DefaultMaximumSpeed)

        try p.assertTrain(inBlock: "b1", position: 2, speed: LayoutFactory.DefaultMaximumSpeed)

        try p.triggerFeedback("f21")
        
        try p.assertTrain(inBlock: "b1", position: 1, speed: LayoutFactory.DefaultMaximumSpeed)
        try p.assertTrain(inBlock: "b2", position: 1, speed: LayoutFactory.DefaultMaximumSpeed)
        
        try p.triggerFeedback("f21", false)
        try p.triggerFeedback("f22")
        
        try p.assertTrain(inBlock: "b1", position: 2, speed: LayoutFactory.DefaultMaximumSpeed)
        try p.assertTrain(inBlock: "b2", position: 2, speed: LayoutFactory.DefaultMaximumSpeed)
        
        try p.triggerFeedback("f22", false)
        try p.triggerFeedback("f31")
        
        try p.assertTrain(inBlock: "b1", position: 1, speed: LayoutFactory.DefaultMaximumSpeed)
        try p.assertTrain(inBlock: "b2", position: 1, speed: LayoutFactory.DefaultMaximumSpeed)
        try p.assertTrain(inBlock: "b3", position: 1, speed: LayoutFactory.DefaultMaximumSpeed)
        
        try p.triggerFeedback("f31", false)
        try p.triggerFeedback("f32")
        
        // Train stops because its tail is still in the block b1
        p.layoutController.waitUntilSettled()
        
        try p.assertTrain(inBlock: "b1", position: 2, speed: 0)
        try p.assertTrain(inBlock: "b2", position: 2, speed: 0)
        try p.assertTrain(inBlock: "b3", position: 2, speed: 0)
    }
    
    // MARK: -- Utility
    
    // Convenience structure to test the layout and its route
    private struct Package {
        let doc: LayoutDocument
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
            XCTAssertEqual(train.speed.actualKph, speed, accuracy: 1)
        }
        
        func assertTrain(notInBlock named: String) throws {
            let blockId = Identifier<Block>(uuid: named)
            guard let block = layout.block(for: blockId) else {
                throw LayoutError.blockNotFound(blockId: blockId)
            }

            XCTAssertNil(block.train)
        }
        
        func setTrainSpeed(_ speed: TrainSpeed.UnitKph) {
            let strain = doc.simulator.trains.first(where: { $0.train.id == train.id })!
            let steps = train.speed.steps(for: speed)
            strain.speed = steps
            doc.simulator.setTrainSpeed(train: strain)
            
            waitForSpeed(speed)
        }
                
        func waitForSpeed(_ speed: TrainSpeed.UnitKph) {
            let steps = train.speed.steps(for: speed)
            BTTestCase.wait(for: {
                abs(train.speed.actualSteps.value.distance(to: steps.value)) <= 1
            }, timeout: 2.0)
        }
        
        func triggerFeedback(_ named: String, _ detected: Bool = true) throws {
            let feedbackId = Identifier<Feedback>(uuid: named)
            guard let feedback = layout.feedback(for: feedbackId) else {
                throw LayoutError.feedbackNotFound(feedbackId: feedbackId)
            }

            feedback.detected = detected
            layoutController.runControllers(.feedbackTriggered(feedback))
        }
    }
    
    private func setup(layout: Layout, fromBlockId: String, position: Position = .start, direction: Direction = .next) throws -> Package {
        layout.detectUnexpectedFeedback = true
        layout.strictRouteFeedbackStrategy = true

        let train = layout.trains[0]
        
        let doc = LayoutDocument(layout: layout)

        try doc.layoutController.setTrainToBlock(train, Identifier<Block>(uuid: fromBlockId), position: position, direction: direction)
        
        XCTAssertEqual(train.speed.requestedKph, 0)
        XCTAssertEqual(train.scheduling, .unmanaged)
        XCTAssertEqual(train.state, .stopped)

        let asserter = LayoutAsserter(layout: layout, layoutController: doc.layoutController)
        return Package(doc: doc, layout: layout, train: train, asserter: asserter, layoutController: doc.layoutController)
    }

}
