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
        let layout =  LayoutIncomplete().newLayout()
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
        let errors = try diag.check(.skipLengths)
        XCTAssertEqual(errors.count, 8)
        
        let turnout = layout.turnouts[0]
        XCTAssertEqual(errors[1], DiagnosticError.turnoutMissingTransition(turnout: turnout, socket: turnout.socketName(turnout.socket0.socketId!)))
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
            try layout.remove(trainID: Identifier<Train>(uuid: "foo"))
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
            XCTAssertEqual(error.localizedDescription, "Turnout t1 not found")
        }
    }

    func testBlockNotEmpty() {
        do {
            try layout.setTrainToBlock(train0.id, b1.id, direction: .next)
            try layout.setTrainToBlock(train1.id, b1.id, direction: .next)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Block b1 is not empty")
        }
    }

    func testNoTransitions() {
        do {
            b1.train = .init(train1.id, .next)
            _ = try layout.entryFeedback(from: b1, to: b2)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "No transition found from block b1 to block b2")
        }
    }

    func testCannotReserveBlock() {
        do {
            b1.reserved = Reservation(trainId: train1.id, direction: .next)
            try layout.setTrainToBlock(train0.id, b1.id, direction: .next)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Cannot reserve block 1 for train lw1 because the block is already reserved for Reservation(train=lw2, direction=next)")
        }
    }
    
    func testAlwaysOneTransition() {
        do {
            layout.link(from: b1.next, to: turnout.socket0)
            layout.link(from: turnout.socket1, to: b2.previous)
            layout.transitions[1].b = .init(block: b1.id, turnout: nil, socketId: nil)
            _  = try layout.transition(from: b1.next)
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
            XCTAssertEqual(error.localizedDescription, "Train lw1 does not have any assigned block (train.blockId is nil)")
        }
    }
    
    func testTrainNotFoundInBlock() {
        do {
            train0.blockId = b1.id
            _ = try layout.directionDirectionInBlock(train0)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Block b1 does not have any train assigned to it (TrainInstance is nil)")
        }
    }

    func testTrainInBlockDoesNotMatch() {
        do {
            train0.blockId = b1.id
            b1.train = .init(train1.id, .next)
            _ = try layout.directionDirectionInBlock(train0)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Block b1 has another train (lw2) than lw1 assigned to it")
        }
    }
    
    func testRouteNotFound() {
        do {
            let doc = LayoutDocument(layout: layout)
            try doc.start(train: train0.id, withRoute: Identifier<Route>(uuid: "foo"), destination: nil)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Route foo not found")
        }
    }

}
