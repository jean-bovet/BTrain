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

class LayoutTests: XCTestCase {

    func testValidation() throws {
        let layout = LayoutComplexLoop().newLayout()
        let diag = LayoutDiagnostic(layout: layout)
        let errors = try diag.check(.skipLengths)
        XCTAssertEqual(errors.count, 0)
    }

    func testAddAndRemoveBlock() throws {
        let layout = Layout()
        
        let t1 = layout.addTrain(Train(uuid: "t1", name: "t1", address: 0))
        let b1 = layout.newBlock(name: "b1", category: .free)
        let b2 = layout.newBlock(name: "b2", category: .free)
        layout.link(from: b1.next, to: b2.previous)
        layout.link(from: b2.next, to: b1.previous)

        try layout.setTrainToBlock(t1.id, b1.id, direction: .next)
        XCTAssertEqual(t1.blockId, b1.id)
        XCTAssertEqual(layout.transitions.count, 2)

        let b11 = layout.block(for: b1.id)
        XCTAssertTrue(b1 === b11)
        
        layout.remove(blockID: b1.id)
        XCTAssertNil(layout.block(for: b1.id))
        XCTAssertNil(t1.blockId)
        XCTAssertEqual(layout.transitions.count, 0)
    }

    func testAddAndRemoveFeedback() throws {
        let layout = Layout()
        let b1 = layout.newBlock(name: "b1", category: .free)

        let f1 = layout.newFeedback()
        layout.assign(b1, [f1])
        XCTAssertEqual(b1.feedbacks.count, 1)

        let f11 = layout.feedback(for: f1.id)
        XCTAssertEqual(f1, f11)
        
        layout.remove(feedbackID: f1.id)
        XCTAssertNil(layout.feedback(for: f1.id))
        XCTAssertEqual(b1.feedbacks.count, 0)
    }
    
    func testAddAndRemoveTurnout() throws {
        let layout = Layout()
        let b1 = layout.newBlock(name: "b1", category: .free)

        let t1 = layout.newTurnout(name: "t1", category: .doubleSlip)
        layout.link(from: b1.next, to: t1.socket0)
        layout.link(from: t1.socket1, to: b1.previous)
        XCTAssertEqual(layout.transitions.count, 2)

        let t11 = layout.turnout(for: t1.id)
        XCTAssertEqual(t1, t11)
        
        layout.remove(turnoutID: t1.id)
        XCTAssertNil(layout.turnout(for: t1.id))
        XCTAssertEqual(layout.transitions.count, 0)
    }
    
    func testTrainDirection() throws {
        let layout = LayoutFigure8().newLayout()
        let train1 = layout.trains[0]
        let block1 = layout.blocks[0]
        
        try layout.setTrainToBlock(train1.id, block1.id, direction: .next)
        
        XCTAssertEqual(train1.directionForward, true)

        // Set the train direction
        layout.setLocomotiveDirection(train1, forward: false)
        XCTAssertEqual(train1.directionForward, false)

        // Set the train inside a block with a specific direction which
        // is opposite of the train direction itself
        try layout.setTrainToBlock(train1.id, block1.id, direction: .next)
        XCTAssertEqual(block1.train!.direction, .next)
        XCTAssertEqual(train1.directionForward, false)

        // Change the train direction - which should not affect the direction
        // of the train within the block (we need to explicitly call the toggle
        // method for this to happen!)
        layout.setLocomotiveDirection(train1, forward: true)
        XCTAssertEqual(train1.directionForward, true)
        XCTAssertEqual(block1.train!.direction, .next)
        
        // Now toggle the direction within the block itself
        try layout.toggleTrainDirectionInBlock(train1)
        XCTAssertEqual(train1.directionForward, true)
        XCTAssertEqual(block1.train!.direction, .previous)
    }
    
    func testTrainStopCompletely() throws {
        let doc = LayoutDocument(layout: LayoutFigure8().newLayout())
        let layout = doc.layout
        let train1 = layout.trains[0]
        let block1 = layout.blocks[0]

        try layout.setTrainToBlock(train1.id, block1.id, direction: .next)

        connectToSimulator(doc: doc) { }

        defer {
            disconnectFromSimulator(doc: doc)
        }
        
        XCTAssertEqual(train1.state, .stopped)
        XCTAssertTrue(train1.manualScheduling)

        try layout.start(routeID: layout.routes[0].id, trainID: train1.id, destination: nil)
        
        doc.layoutController.runControllers(.stateChanged)
        
        XCTAssertEqual(train1.state, .running)
        XCTAssertTrue(train1.automaticScheduling)

        let stopped = expectation(description: "Stopped")
        try layout.stopTrain(train1.id, completely: false) {
            stopped.fulfill()
        }

        XCTAssertEqual(train1.state, .stopping)
        XCTAssertTrue(train1.automaticScheduling)

        wait(for: [stopped], timeout: 2.0)
        
        XCTAssertEqual(train1.state, .stopped)
        XCTAssertTrue(train1.automaticScheduling)

        let stoppedFully = expectation(description: "StoppedFully")
        try layout.stopTrain(train1.id, completely: true) {
            stoppedFully.fulfill()
        }
        wait(for: [stoppedFully], timeout: 2.0)

        XCTAssertEqual(train1.state, .stopped)
        XCTAssertTrue(train1.manualScheduling)
    }
  
    func testBlockSpeedLimit() throws {
        let layout = LayoutLoopWithStation().newLayout()
        let train = layout.trains[0]
        let s1 = layout.block(named: "s1")
        let b1 = layout.block(named: "b1")

        try layout.setTrainToBlock(train.id, s1.id, direction: .next)

        train.leadingBlocks = [s1, b1]
        train.startRouteIndex = 0

        XCTAssertEqual(layout.reservation.maximumSpeedAllowed(train: train), LayoutFactory.DefaultMaximumSpeed)
        
        s1.speedLimit = .limited
        XCTAssertEqual(layout.reservation.maximumSpeedAllowed(train: train), LayoutFactory.DefaultLimitedSpeed)
    }

    func testTurnoutSpeedLimit() throws {
        let doc = LayoutDocument(layout: LayoutLoopWithStation().newLayout())
        let layout = doc.layout
        let train = layout.trains[0]
        let s1 = layout.block(named: "s1")
        let b1 = layout.block(named: "b1")

        try layout.setTrainToBlock(train.id, s1.id, direction: .next)
        
        train.leadingBlocks = [s1, b1]
        train.startRouteIndex = 0

        XCTAssertEqual(layout.reservation.maximumSpeedAllowed(train: train), LayoutFactory.DefaultMaximumSpeed)

        let b2 = layout.block(named: "b2")
        let route = layout.newRoute(id: "s1-b2", [(s1.id.uuid, .next), (b2.id.uuid, .next)])
        
        try doc.start(train: train.id, withRoute: route.id, destination: .init(b2.id, direction: .next))
        
        XCTAssertEqual(layout.reservation.maximumSpeedAllowed(train: train), LayoutFactory.DefaultLimitedSpeed)
    }
}
