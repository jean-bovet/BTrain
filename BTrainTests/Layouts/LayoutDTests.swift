//
//  LayoutErrorTests.swift
//  BTrainTests
//
//  Created by Jean Bovet on 12/15/21.
//

import XCTest

@testable import BTrain

class LayoutErrorTests: LayoutTests {
    override var layoutID: Identifier<Layout>? {
        LayoutDCreator.id
    }

    func testDiagnostic() {
        let diag = LayoutDiagnostic(layout: layout)
        let errors = diag.check()
        XCTAssertEqual(errors.count, 7)

        let turnout = layout.turnouts[0]
        XCTAssertEqual(errors[0], DiagnosticError.turnoutMissingTransition(turnoutId: turnout.id, socket: turnout.socketName(turnout.socket0.socketId!)))
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
            try layout.free(trainID: Identifier<Train>(uuid: "foo"), removeFromLayout: false)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Train foo not found")
        }
    }

    func testMissingTurnout() throws {
        let b1 = layout.blocks[0]
        let turnout = layout.turnouts[0]
        layout.link(from: b1.next, to: turnout.socket0)
        layout.turnouts.removeAll()
        do {
            try layout.free(fromBlock: layout.blockIds[0], toBlockNotIncluded: layout.blockIds[1], direction: .next)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Turnout 0 not found")
        }
    }

    func testBlockNotEmpty() {
        do {
            try layout.setTrain(layout.trains[0].id, toBlock: layout.blockIds[0], direction: .next)
            try layout.setTrain(layout.trains[1].id, toBlock: layout.blockIds[0], direction: .next)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Block 1 is not empty")
        }
    }

    func testNoTransitions() {
        do {
            try layout.reserve(train: layout.trains[0].id, fromBlock: layout.blockIds[0], toBlock: layout.blockIds[1], direction: .next)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "No transition found from block 1 to block 2")
        }
    }

    func testCannotReserveTransition() {
        do {
            layout.link(from: layout.blocks[0].next, to: layout.turnouts[0].socket0)
            layout.transitions[0].reserved = layout.trains[1].id
            try layout.transitions.canReserve(for: layout.trains[0].id, layout: layout)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Cannot reserve transition 0 for train 1 because the transition is already reserved for 2")
        }
    }

    func testCannotReserveTurnout() {
        do {
            layout.link(from: layout.blocks[0].next, to: layout.turnouts[0].socket0)
            layout.link(from: layout.turnouts[0].socket1, to: layout.blocks[1].previous)
            layout.turnouts[0].reserved = layout.trains[1].id
            try layout.transitions.canReserve(for: layout.trains[0].id, layout: layout)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Cannot reserve turnout 0 for train 1 because the turnout is already reserved for 2")
        }
    }

    func testCannotReserveBlock() {
        do {
            layout.mutableBlocks[0].reserved = layout.trains[1].id
            try layout.reserve(block: layout.blockIds[0], withTrain: layout.mutableTrains[0])
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Cannot reserve block 1 for train 1 because the block is already reserved for 2")
        }
    }

    var train0: Train {
        layout.mutableTrains[0]
    }

    var b1: Block {
        layout.mutableBlocks[0]
    }

    var b2: Block {
        layout.mutableBlocks[1]
    }

    var turnout: Turnout {
        layout.turnouts[0]
    }

    func testSocketIdNotFond() {
        do {
            layout.link(from: layout.blocks[0].next, to: layout.turnouts[0].socket0)
            layout.link(from: layout.turnouts[0].socket1, to: layout.blocks[1].previous)
            layout.transitions[1].a = .init(block: nil, turnout: turnout.id, socketId: nil)
            try layout.reserve(train: train0.id, fromBlock: b1.id, toBlock: b2.id, direction: .next)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "There is no socket defined for Socket[block 1, socket 1]")
        }
    }

    func testAlwaysOneTransition() {
        do {
            layout.link(from: layout.blocks[0].next, to: layout.turnouts[0].socket0)
            layout.link(from: layout.turnouts[0].socket1, to: layout.blocks[1].previous)
            layout.transitions[1].b = .init(block: b1.id, turnout: nil, socketId: nil)
            try layout.reserve(train: train0.id, fromBlock: b1.id, toBlock: b2.id, direction: .next)
            XCTFail("Must throw an exception")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Cannot reserve block 1 for train 1 because the block is already reserved for 2")
        }
    }
}
