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

//                  ┌─────────┐
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
//                                   └─────────┘
class UnmanagedTrainOperationTests: BTTestCase {
    // b1 > b2 > b1
    func testFollowTrainForward() throws {
        let layout = LayoutLoop1().newLayout()
        let p = try setup(layout: layout, fromBlockId: "b1")

        connectToSimulator(doc: p.doc)
        defer {
            disconnectFromSimulator(doc: p.doc)
        }

        p.setTrainSpeed(LayoutFactory.DefaultMaximumSpeed)

        try p.assertTrain(inBlock: "b1", position: 2, speed: LayoutFactory.DefaultMaximumSpeed)

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

    // !b1 > !b2 > !b1
    func testFollowTrainBackward() throws {
        let layout = LayoutLoop1().newLayout()
        let p = try setup(layout: layout, fromBlockId: "b1")
        p.train.isTailDetected = true
        
        connectToSimulator(doc: p.doc)
        defer {
            disconnectFromSimulator(doc: p.doc)
        }

        p.setTrainSpeed(LayoutFactory.DefaultMaximumSpeed)
        try p.toggleDirection()

        try p.assertTrain(inBlock: "b1", position: 1, speed: LayoutFactory.DefaultMaximumSpeed)

        try p.triggerFeedback("f22")

        try p.assertTrain(notInBlock: "b1")
        try p.assertTrain(inBlock: "b2", position: 1, speed: LayoutFactory.DefaultMaximumSpeed)

        try p.triggerFeedback("f22", false)
        try p.triggerFeedback("f21")

        try p.assertTrain(notInBlock: "b1")
        try p.assertTrain(inBlock: "b2", position: 0, speed: LayoutFactory.DefaultMaximumSpeed)

        try p.triggerFeedback("f21", false)
        try p.triggerFeedback("f12")

        try p.assertTrain(notInBlock: "b2")
        try p.assertTrain(inBlock: "b1", position: 1, speed: LayoutFactory.DefaultMaximumSpeed)

        try p.triggerFeedback("f12", false)
        try p.triggerFeedback("f11")

        p.doc.layoutController.waitUntilSettled()

        try p.assertTrain(notInBlock: "b2")
        try p.assertTrain(inBlock: "b1", position: 0, speed: LayoutFactory.DefaultMaximumSpeed)
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
            if train.directionForward {
                XCTAssertEqual(train.positions.head?.index, position, "Head position mismatch")
            } else {
                XCTAssertEqual(train.positions.tail?.index, position, "Tail position mismatch")
            }
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
            doc.simulator.setLocomotiveSpeed(locomotive: strain)

            waitForSpeed(speed)
        }

        func toggleDirection() throws {
            try doc.layoutController.toggleTrainDirection(train)
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

    private func setup(layout: Layout, fromBlockId: String, positionAtEnd _: Bool = false, direction: Direction = .next) throws -> Package {
        layout.detectUnexpectedFeedback = true

        let train = layout.trains[0]
        let loc = train.locomotive!
        let doc = LayoutDocument(layout: layout)
        let block = layout.blocks[Identifier<Block>(uuid: fromBlockId)]!

        try doc.layoutController.setupTrainToBlock(train, block.id, naturalDirectionInBlock: direction)

        XCTAssertEqual(loc.speed.requestedKph, 0)
        XCTAssertEqual(train.scheduling, .unmanaged)
        XCTAssertEqual(train.state, .stopped)

        let asserter = LayoutAsserter(layout: layout, layoutController: doc.layoutController)
        return Package(doc: doc, layout: layout, train: train, loc: loc, asserter: asserter, layoutController: doc.layoutController)
    }
}
