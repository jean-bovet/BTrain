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

@testable import BTrain
import XCTest

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

        try p.triggerFeedback("f11", false)
        try p.triggerFeedback("f12")

        p.doc.layoutController.waitUntilSettled()

        try p.assertTrain(notInBlock: "b2")
        try p.assertTrain(inBlock: "b1", position: 2, speed: LayoutFactory.DefaultMaximumSpeed)
    }

    //                 ┌─────────┐
    // ┌────────────────│ Block 2 │◀────────────────────┐
    // │                └─────────┘                     │
    // │                                                │
    // │                                                │
    // │                ┌─────────┐
    // │       ┌───────▶│ Block 3 │────────────────▶Turnout12
    // │       │        └─────────┘
    // │       │                                        ▲
    // │       │                                        │
    // │                                 ┌─────────┐    │
    // └─▶Turnout21 ────────────────────▶│ Block 1 │────┘
    //                                  └─────────┘
    // b1 > b2 > b3 > !b1
    // TODO: semi-automatic mode
    func disabled_testPullingLongTrain() throws {
        let layout = LayoutLoop1().newLayout()

        layout.turnouts[1].setState(.branchLeft)

        layout.turnouts.elements.forEach { $0.length = nil }

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
        train.locomotive!.length = 20
        train.wagonsLength = 40

        let p = try setup(layout: layout, fromBlockId: "b1", positionAtEnd: true)

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

    // MARK: - - Utility

    // Convenience structure to test the layout and its route
    private struct Package {
        let doc: LayoutDocument
        let layout: Layout
        let train: Train
        let loc: Locomotive
        let asserter: LayoutAsserter
        let layoutController: LayoutController

        func assertTrain(inBlock named: String, position: Int, speed: SpeedKph) throws {
            let blockId = Identifier<Block>(uuid: named)
            guard let block = layout.blocks[blockId] else {
                throw LayoutError.blockNotFound(blockId: blockId)
            }

            XCTAssertEqual(block.trainInstance?.trainId, train.id)
            XCTAssertEqual(train.position.front?.index, position)
            XCTAssertEqual(train.position.back?.index, position)
            XCTAssertEqual(loc.speed.actualKph, speed, accuracy: 1)
        }

        func assertTrain(notInBlock named: String) throws {
            let blockId = Identifier<Block>(uuid: named)
            guard let block = layout.blocks[blockId] else {
                throw LayoutError.blockNotFound(blockId: blockId)
            }

            XCTAssertNil(block.trainInstance)
        }

        func setTrainSpeed(_ speed: SpeedKph) {
            let strain = doc.simulator.locomotives.first(where: { $0.loc.id == loc.id })!
            let steps = loc.speed.steps(for: speed)
            strain.speed = steps
            doc.simulator.setTrainSpeed(train: strain)

            waitForSpeed(speed)
        }

        func waitForSpeed(_ speed: SpeedKph) {
            let steps = loc.speed.steps(for: speed)
            BTTestCase.wait(for: {
                abs(loc.speed.actualSteps.value.distance(to: steps.value)) <= 1
            }, timeout: 2.0)
        }

        func triggerFeedback(_ named: String, _ detected: Bool = true) throws {
            let feedbackId = Identifier<Feedback>(uuid: named)
            guard let feedback = layout.feedbacks[feedbackId] else {
                throw LayoutError.feedbackNotFound(feedbackId: feedbackId)
            }

            feedback.detected = detected
            layoutController.runControllers(.feedbackTriggered(feedback))
        }
    }

    private func setup(layout: Layout, fromBlockId: String, positionAtEnd: Bool = false, direction: Direction = .next) throws -> Package {
        layout.detectUnexpectedFeedback = true
        layout.strictRouteFeedbackStrategy = true

        let train = layout.trains[0]
        let loc = train.locomotive!
        let doc = LayoutDocument(layout: layout)
        let block = layout.blocks[Identifier<Block>(uuid: fromBlockId)]!
        
        let location: TrainLocation
        if positionAtEnd {
            location = TrainLocation.both(blockIndex: 0, index: block.feedbacks.count)
        } else {
            location = TrainLocation.both(blockIndex: 0, index: 0)
        }
        try doc.layoutController.setTrainToBlock(train, block.id, position: location, direction: direction)

        XCTAssertEqual(loc.speed.requestedKph, 0)
        XCTAssertEqual(train.scheduling, .unmanaged)
        XCTAssertEqual(train.state, .stopped)

        let asserter = LayoutAsserter(layout: layout, layoutController: doc.layoutController)
        return Package(doc: doc, layout: layout, train: train, loc: loc, asserter: asserter, layoutController: doc.layoutController)
    }
}
