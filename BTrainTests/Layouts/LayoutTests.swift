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

class LayoutTests: BTTestCase {
    func testAddAndRemoveBlock() throws {
        let layout = Layout()

        let t1 = layout.trains.add(Train(uuid: "t1", name: "t1"))
        let b1 = layout.newBlock(name: "b1", category: .free)
        let b2 = layout.newBlock(name: "b2", category: .free)
        layout.link(from: b1.next, to: b2.previous)
        layout.link(from: b2.next, to: b1.previous)

        try layout.setTrainToBlock(t1.id, b1.id, direction: .next)
        XCTAssertEqual(t1.blockId, b1.id)
        XCTAssertEqual(layout.transitions.elements.count, 2)

        let b11 = layout.blocks[b1.id]
        XCTAssertTrue(b1 === b11)

        layout.remove(blockID: b1.id)
        XCTAssertNil(layout.blocks[b1.id])
        XCTAssertNil(t1.blockId)
        XCTAssertEqual(layout.transitions.elements.count, 0)
    }

    func testAddAndRemoveFeedback() throws {
        let layout = Layout()
        let b1 = layout.newBlock(name: "b1", category: .free)

        let f1 = layout.newFeedback()
        layout.assign(b1, [f1])
        XCTAssertEqual(b1.feedbacks.count, 1)

        let f11 = layout.feedbacks[f1.id]
        XCTAssertEqual(f1, f11)

        layout.remove(feedbackID: f1.id)
        XCTAssertNil(layout.feedbacks[f1.id])
        XCTAssertEqual(b1.feedbacks.count, 0)
    }

    func testAddAndRemoveTurnout() throws {
        let layout = Layout()
        let b1 = layout.newBlock(name: "b1", category: .free)

        let t1 = layout.newTurnout(name: "t1", category: .doubleSlip)
        layout.link(from: b1.next, to: t1.socket0)
        layout.link(from: t1.socket1, to: b1.previous)
        XCTAssertEqual(layout.transitions.elements.count, 2)

        let t11 = layout.turnouts[t1.id]
        XCTAssertEqual(t1, t11)

        layout.remove(turnoutID: t1.id)
        XCTAssertNil(layout.turnouts[t1.id])
        XCTAssertEqual(layout.transitions.elements.count, 0)
    }

    func testTrainDirection() throws {
        let interface = MockCommandInterface()
        let doc = LayoutDocument(layout: LayoutFigure8().newLayout(), interface: interface)
        let train1 = doc.layout.trains[0]
        let block1 = doc.layout.blocks[0]

        try doc.layout.setTrainToBlock(train1.id, block1.id, direction: .next)
        XCTAssertEqual(train1.directionForward, true)

        // Change the train direction
        doc.layoutController.setLocomotiveDirection(train1.locomotive!, forward: false)
        wait(for: {
            train1.directionForward == false
        }, timeout: 1.0)
        XCTAssertEqual(train1.directionForward, false)
        XCTAssertEqual(block1.trainInstance!.direction, .previous)

        // Set the train inside a block with a specific direction which
        // is opposite of the train direction itself
        try doc.layout.setTrainToBlock(train1.id, block1.id, direction: .next)
        XCTAssertEqual(block1.trainInstance!.direction, .next)
        XCTAssertEqual(train1.directionForward, false)

        // Change the train direction
        doc.layoutController.setLocomotiveDirection(train1.locomotive!, forward: true)
        wait(for: {
            train1.directionForward == true
        }, timeout: 1.0)

        XCTAssertEqual(train1.directionForward, true)
        XCTAssertEqual(block1.trainInstance!.direction, .previous)
    }

    func testTrainStopCompletely() throws {
        let p = Package(layout: LayoutFigure8().newLayout())
        let train1 = p.layout.trains[0]
        let block1 = p.layout.blocks[0]

        try p.prepare(trainID: train1.id.uuid, fromBlockId: block1.id.uuid)

        try p.start(routeID: p.layout.routes[0].id.uuid, trainID: train1.id.uuid)

        p.stop()
        p.layoutController.waitUntilSettled()

        XCTAssertEqual(train1.scheduling, .stopManaged)

        // Need to trigger braking feedback to start braking
        p.toggle("f11")

        // Need to trigger stop feedback to start braking
        p.toggle("f12")

        XCTAssertEqual(train1.state, .stopped)
        XCTAssertEqual(train1.scheduling, .unmanaged)
    }
}
