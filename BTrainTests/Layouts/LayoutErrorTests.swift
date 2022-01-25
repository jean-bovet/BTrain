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

class LayoutErrorTests: XCTestCase {
    
    lazy var layout: Layout = {
        let layout =  LayoutFactory.createLayout(LayoutDCreator.id)
        return layout
    }()
    
    var train0: Train {
        return layout.trains[0]
    }
    
    var train1: Train {
        return layout.trains[1]
    }
    
    var b1: Block {
        return layout.block(at: 0)
    }
    
    var b2: Block {
        return layout.block(at: 1)
    }

    var turnout: Turnout {
        return layout.turnouts[0]
    }
    
    func testDiagnostic() throws {
        let diag = LayoutDiagnostic(layout: layout)
        let errors = try diag.check()
        XCTAssertEqual(errors.count, 7)
        
        let turnout = layout.turnouts[0]
        XCTAssertEqual(errors[0], DiagnosticError.turnoutMissingTransition(turnout: turnout, socket: turnout.socketName(turnout.socket0.socketId!)))
    }
    
    func testMissingBlock() {
        let unknownBlock = Identifier<Block>(uuid: "foo")
        do {
            try layout.free(block: unknownBlock)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Block foo not found")
        }
    }
    
    func testMissingTrain() {
        do {
            try layout.free(trainID: Identifier<Train>(uuid: "foo"))
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Train foo not found")
        }
    }

    func testMissingTurnout() throws {
        layout.link(from: b1.next, to: turnout.socket0)
        layout.turnouts.removeAll()
        do {
            try layout.free(fromBlock: b1.id, toBlockNotIncluded: b2.id, direction: .next)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Turnout 0 not found")
        }
    }

    func testBlockNotEmpty() {
        do {
            try layout.setTrainToBlock(train0.id, b1.id, direction: .next)
            try layout.setTrainToBlock(train1.id, b1.id, direction: .next)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Block 1 is not empty")
        }
    }

    func testNoTransitions() {
        do {
            try layout.reserve(trainId: train1.id, fromBlock: b1.id, toBlock: b2.id, direction: .next)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "No transition found from block 1 to block 2")
        }
    }

    func testCannotReserveTransition() {
        do {
            layout.link("0", from: b1.next, to: turnout.socket0)
            layout.transitions[0].reserved = train1.id
            try Transition.canReserve(transitions: layout.transitions, for: train0.id, layout: layout)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Cannot reserve transition 0 for train 1 because the transition is already reserved for 2 (2)")
        }
    }

    func testCannotReserveTurnout() {
        do {
            layout.link(from: b1.next, to: turnout.socket0)
            layout.link(from: turnout.socket1, to: b2.previous)
            turnout.reserved = train1.id
            try Transition.canReserve(transitions: layout.transitions, for: train0.id, layout: layout)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Cannot reserve turnout 0 for train 1 because the turnout is already reserved for 2")
        }
    }

    func testCannotReserveBlock() {
        do {
            b1.reserved = Reservation(trainId: train1.id, direction: .next)
            try layout.setTrainToBlock(train0.id, b1.id, direction: .next)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Cannot reserve block 1 for train 1 because the block is already reserved for Reservation(train=2, direction=next)")
        }
    }

    func testSocketIdNotFond() {
        do {
            layout.link(from: b1.next, to: turnout.socket0)
            layout.link(from: turnout.socket1, to: b2.previous)
            layout.transitions[1].a = .init(block: nil, turnout: turnout.id, socketId: nil)
            try layout.reserve(trainId: train0.id, fromBlock: b1.id, toBlock: b2.id, direction: .next)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "There is no socket defined for Socket[block 1, socket 1]")
        }
    }

    func testAlwaysOneTransition() {
        do {
            layout.link(from: b1.next, to: turnout.socket0)
            layout.link(from: turnout.socket1, to: b2.previous)
            layout.transitions[1].b = .init(block: b1.id, turnout: nil, socketId: nil)
            try layout.reserve(trainId: train0.id, fromBlock: b1.id, toBlock: b2.id, direction: .next)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "There must always be only one and only one transition")
        }
    }

    func testTrainNotAssignedToABlock() {
        do {
            train0.blockId = nil
            _ = try layout.directionDirectionInBlock(train0)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Train 1 does not have any assigned block (train.blockId is nil)")
        }
    }
    
    func testTrainNotFoundInBlock() {
        do {
            train0.blockId = b1.id
            _ = try layout.directionDirectionInBlock(train0)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Block 1 does not have any train assigned to it (TrainInstance is nil)")
        }
    }

    func testTrainInBlockDoesNotMatch() {
        do {
            train0.blockId = b1.id
            b1.train = .init(train1.id, .next)
            _ = try layout.directionDirectionInBlock(train0)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Block 1 has another train (2) than 1 assigned to it")
        }
    }
    
    func testRouteNotFound() {
        do {
            try layout.prepare(routeID: Identifier<Route>(uuid: "foo"), trainID: train0.id)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Route foo not found")
        }
    }

    func testNoStepsInRoute() {
        do {
            layout.routes[0].steps.removeAll()
            try layout.prepare(routeID:layout.routes[0].id, trainID: train0.id)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "No steps defined in route 0")
        }
    }

}
