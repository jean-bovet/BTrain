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
        let doc = LayoutDocument(layout: LayoutFigure8().newLayout())
        let train1 = doc.layout.trains[0]
        let block1 = doc.layout.blocks[0]
        
        connectToSimulator(doc: doc) { }

        defer {
            disconnectFromSimulator(doc: doc)
        }

        try doc.layout.setTrainToBlock(train1.id, block1.id, direction: .next)
        XCTAssertEqual(train1.directionForward, true)

        // Change the train direction
        doc.layout.setLocomotiveDirection(train1, forward: false)
        wait(for: {
            train1.directionForward == false
        }, timeout: 0.1)
        XCTAssertEqual(train1.directionForward, false)
        XCTAssertEqual(block1.train!.direction, .previous)

        // Set the train inside a block with a specific direction which
        // is opposite of the train direction itself
        try doc.layout.setTrainToBlock(train1.id, block1.id, direction: .next)
        XCTAssertEqual(block1.train!.direction, .next)
        XCTAssertEqual(train1.directionForward, false)

        // Change the train direction
        doc.layout.setLocomotiveDirection(train1, forward: true)
        wait(for: {
            train1.directionForward == true
        }, timeout: 0.1)

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
        XCTAssertTrue(train1.unmanagedScheduling)
        try doc.start(train: train1.id, withRoute: layout.routes[0].id, destination: nil)
        
        XCTAssertEqual(train1.state, .running)
        XCTAssertTrue(train1.managedScheduling)

        let stopped = expectation(description: "Stopped")
        try layout.stopTrain(train1.id, completely: false) {
            stopped.fulfill()
        }

        XCTAssertEqual(train1.state, .stopping)
        XCTAssertTrue(train1.managedScheduling)

        wait(for: [stopped], timeout: 2.0)
        
        XCTAssertEqual(train1.state, .stopped)
        XCTAssertTrue(train1.managedScheduling)

        let stoppedFully = expectation(description: "StoppedFully")
        try layout.stopTrain(train1.id, completely: true) {
            stoppedFully.fulfill()
        }
        wait(for: [stoppedFully], timeout: 2.0)

        XCTAssertEqual(train1.state, .stopped)
        XCTAssertTrue(train1.unmanagedScheduling)
    }
  
    func testBlockSpeedLimit() throws {
        let layout = LayoutLoopWithStation().newLayout()
        let train = layout.trains[0]
        
        let s1 = layout.block(named: "s1")
        let b1 = layout.block(named: "b1")

        try layout.setTrainToBlock(train.id, s1.id, direction: .next)

        train.leadingBlocks = [s1, b1]
        train.startRouteIndex = 0

        XCTAssertEqual(layout.reservation.maximumSpeedAllowed(train: train, route: nil), LayoutFactory.DefaultMaximumSpeed)
        
        s1.speedLimit = .limited
        XCTAssertEqual(layout.reservation.maximumSpeedAllowed(train: train, route: nil), LayoutFactory.DefaultLimitedSpeed)
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

        XCTAssertEqual(layout.reservation.maximumSpeedAllowed(train: train, route: nil), LayoutFactory.DefaultMaximumSpeed)

        let b2 = layout.block(named: "b2")
        let route = layout.newRoute(id: "s1-b2", [(s1.id.uuid, .next), (b2.id.uuid, .next)])
        
        try doc.start(train: train.id, withRoute: route.id, destination: .init(b2.id, direction: .next))
        
        XCTAssertEqual(layout.reservation.maximumSpeedAllowed(train: train, route: route), LayoutFactory.DefaultLimitedSpeed)
    }
    
    func testLayout() throws {
        let layout = LayoutLoop1().newLayout()
        let train = layout.trains[0]
        
        try layout.prepare(routeID: layout.routes[0].id, trainID: layout.trains[0].id)
        
        // Assert the expectations before the train circulates
        guard let route = layout.route(for: train.routeId, trainId: train.id) else {
            XCTFail("Unable to find route \(train.routeId)")
            return
        }
        XCTAssertEqual(4, route.steps.count)
        
        let b1 = route.blockSteps[0]
        let b2 = route.blockSteps[1]
        let b3 = route.blockSteps[2]
        let b4 = route.blockSteps[3]

        XCTAssertNotEqual(b1.blockId, b2.blockId)
        XCTAssertNotEqual(b2.blockId, b3.blockId)
        XCTAssertNotEqual(b3.blockId, b1.blockId)
        XCTAssertEqual(b4.blockId, b1.blockId)

        XCTAssertEqual(b1.blockId, layout.currentBlock(train: train)?.id)
        
        let transitions = try layout.transitions(from: b1.blockId, to: b2.blockId, direction: b1.direction!)
        XCTAssertEqual(transitions.count, 2)
        
        XCTAssertEqual(transitions[0].a.block, b1.blockId)
        XCTAssertNil(transitions[0].a.turnout)
        XCTAssertEqual(transitions[0].a.socketId, Block.nextSocket)
        
        XCTAssertNil(transitions[0].b.block)
        XCTAssertEqual(transitions[0].b.turnout, layout.turnouts[0].id)
        XCTAssertEqual(transitions[0].b.socketId, 0)
        
        XCTAssertEqual(transitions[1].a.turnout, layout.turnouts[0].id)
        XCTAssertNil(transitions[1].a.block)
        XCTAssertEqual(transitions[1].a.socketId, 1)
        
        XCTAssertEqual(transitions[1].b.block, b2.blockId)
        XCTAssertNil(transitions[1].b.turnout)
        XCTAssertEqual(transitions[1].b.socketId, Block.previousSocket)
    }

}
