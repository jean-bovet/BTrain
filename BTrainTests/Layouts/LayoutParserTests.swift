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

class LayoutParserTests: XCTestCase {
    
    func testParseRoute1() {
        let layout = LayoutFactory.layoutFrom("r0:{r0{b1 🛑🚂0 ≏ ≏ }} [r0[b2 ≏ ≏ ]] [b3 ≏ ≏ ] {b4 ≏ ≏ }")
        
        let blocks = [
            BE(type: .station, uuid: "b1", train: TE(uuid: 0, position: 0, speed: 0), reserved: 0),
            BE(type: .free, uuid: "b2", train: nil, reserved: 0),
            BE(type: .free, uuid: "b3", train: nil, reserved: nil),
            BE(type: .station, uuid: "b4", train: nil, reserved: nil),
        ]
        assertLayout(layout: layout, expectations: blocks)
    }
    
    func testParseRoute2() {
        let layout = LayoutFactory.layoutFrom("r0:{b1 ≏ ≏ } [r0[b2 ≏ 🚂0 ≏ ]] [r0[b3 ≏ ≏ ]] {b4 ≏ ≏ }")
        
        let blocks = [
            BE(type: .station, uuid: "b1", train: nil, reserved: nil),
            BE(type: .free, uuid: "b2", train: TE(uuid: 0, position: 1, speed: LayoutFactory.DefaultSpeed), reserved: 0),
            BE(type: .free, uuid: "b3", train: nil, reserved: 0),
            BE(type: .station, uuid: "b4", train: nil, reserved: nil),
        ]
        assertLayout(layout: layout, expectations: blocks)
    }
    
    func testParseRoute3() {
        let layout = LayoutFactory.layoutFrom("r0:{b1 ≏ ≏ } [r0[b2 ≏ 🚂0 ≏ ]] [r0[b3 ≏ ≏ ]] {b1 ≏ ≏ }")
        
        let blocks = [
            BE(type: .station, uuid: "b1", train: nil, reserved: nil),
            BE(type: .free, uuid: "b2", train: TE(uuid: 0, position: 1, speed: LayoutFactory.DefaultSpeed), reserved: 0),
            BE(type: .free, uuid: "b3", train: nil, reserved: 0),
            BE(type: .station, uuid: "b1", train: nil, reserved: nil),
        ]
        assertLayout(layout: layout, expectations: blocks)
    }
    
    func testParseRouteMultipleTrains() {
        let layout = LayoutFactory.layoutFrom("r0:{r0{b1 🛑🚂0 ≏ ≏ }} [r0[b2 ≏ ≏ ]] [r1[b3 🛑🚂1 ≏ ≏ ]] {b4 ≏ ≏ }")
        
        let blocks = [
            BE(type: .station, uuid: "b1", train: TE(uuid: 0, position: 0, speed: 0), reserved: 0),
            BE(type: .free, uuid: "b2", train: nil, reserved: 0),
            BE(type: .free, uuid: "b3", train: TE(uuid: 1, position: 0, speed: 0), reserved: 1),
            BE(type: .station, uuid: "b4", train: nil, reserved: nil),
        ]
        assertLayout(layout: layout, expectations: blocks)
    }
    
    func testParseRouteWithFeedbackDetected() {
        let layout = LayoutFactory.layoutFrom("r0:{b1 ≡ ≏ } [r0[b2 ≏ 🚂0 ≏ ]] [r0[b3 ≏ ≏ ]] {b4 ≏ ≏ }")
        
        let blocks = [
            BE(type: .station, uuid: "b1", train: nil, reserved: nil, feedbacks: [true, false]),
            BE(type: .free, uuid: "b2", train: TE(uuid: 0, position: 1, speed: LayoutFactory.DefaultSpeed), reserved: 0, feedbacks: [false, false]),
            BE(type: .free, uuid: "b3", train: nil, reserved: 0, feedbacks: [false, false]),
            BE(type: .station, uuid: "b4", train: nil, reserved: nil, feedbacks: [false, false]),
        ]
        assertLayout(layout: layout, expectations: blocks)
    }
    
    func testParseRouteWithReservation() {
        let layout = LayoutFactory.layoutFrom("r0:{r0{b1 ≏ ≏ }} [r0[b2 ≏ 🚂0 ≏ ]] [r1[b3 ≏ ≏ ]] {b4 ≏ ≏ }")
        
        let blocks = [
            BE(type: .station, uuid: "b1", train: nil, reserved: 0),
            BE(type: .free, uuid: "b2", train: TE(uuid: 0, position: 1, speed: LayoutFactory.DefaultSpeed), reserved: 0),
            BE(type: .free, uuid: "b3", train: nil, reserved: 1),
            BE(type: .station, uuid: "b4", train: nil, reserved: nil),
        ]
        assertLayout(layout: layout, expectations: blocks)
    }
    
    func testParseRouteWithTurnouts() {
        let layout = LayoutFactory.layoutFrom("r0:{b1 ≏ ≏ } <t0> [r0[b2 ≏ 🚂0 ≏ ]] <t1> [r0[b3 ≏ ≏ ]] <t2,l> {b4 ≏ ≏ }")
        
        let blocks = [
            BE(type: .station, uuid: "b1", turnouts: [T("t0", 0, 1, .straight)]),
            BE(type: .free, uuid: "b2", train: TE(uuid: 0, position: 1, speed: LayoutFactory.DefaultSpeed), reserved: 0, turnouts: [T("t1", 0, 1, .straight)]),
            BE(type: .free, uuid: "b3", reserved: 0, turnouts: [T("t2", 0, 1, .branchLeft)]),
            BE(type: .station, uuid: "b4"),
        ]
        assertLayout(layout: layout, expectations: blocks)
    }
        
    struct BE {
        let type: Block.Category
        let uuid: String
        let train: TE?
        let reserved: Int?
        let feedbacks: [Bool]?
        let turnouts: [T]?
        
        init(type: Block.Category, uuid: String, train: TE? = nil, reserved: Int? = nil, feedbacks: [Bool]? = nil, turnouts: [T]? = nil) {
            self.type = type
            self.uuid = uuid
            self.train = train
            self.reserved = reserved
            self.feedbacks = feedbacks
            self.turnouts = turnouts
        }
    }
    
    struct TE {
        let uuid: Int
        let position: Int
        let speed: UInt16
    }
    
    struct T {
        let id: String
        let fromSocket: Int
        let toSocket: Int
        let state: Turnout.State
        
        init(_ id: String, _ from: Int, _ to: Int, _ state: Turnout.State) {
            self.id = id
            self.fromSocket = from
            self.toSocket = to
            self.state = state
        }
    }
    
    func assertLayout(layout: Layout, expectations: [BE]) {
        let route = layout.routes.first!
        let blockSteps = route.blockSteps
        
        XCTAssertEqual(blockSteps.count, expectations.count)
        
        for (index, expectation) in expectations.enumerated() {
            let step = blockSteps[index]
            let blockId = step.blockId
            
            XCTAssertEqual(blockId, Identifier<Block>(uuid: String(expectation.uuid)), "Mismatching block identifier at index \(index)")
            
            guard let block = layout.block(for: blockId) else {
                XCTFail("Unable to find block \(String(describing: blockId))")
                return
            }
            
            if let expectedTrain = expectation.train {
                let trainId = block.train!.trainId
                let train = layout.train(for: trainId)!
                XCTAssertEqual(train.id, Identifier<Train>(uuid: String(expectedTrain.uuid)), "Unexpected train in block \(index)")
                XCTAssertEqual(train.speed.requestedKph, expectedTrain.speed)
                XCTAssertEqual(train.position, expectedTrain.position)
            } else {
                XCTAssertNil(block.train)
            }
            
            if let reserved = expectation.reserved {
                XCTAssertEqual(block.reserved?.trainId, Identifier<Train>(uuid: String(reserved)), "Mismatching reserved block at \(index)")
            } else {
                XCTAssertNil(block.reserved, "Expected no reservation at index \(index)")
            }
            
            // Assert the feedbacks
            if let feedbacks = expectation.feedbacks {
                XCTAssertEqual(feedbacks.count, block.feedbacks.count)
                for (fi, detected) in feedbacks.enumerated() {
                    let feedback = layout.feedback(for: block.feedbacks[fi].feedbackId)!
                    XCTAssertEqual(feedback.detected, detected, "Unexpected feedback detection at index \(fi)")
                }
            }
            
            // Assert the turnouts
            if let expectedTurnouts = expectation.turnouts {
                let nextStep = route.steps[index+1]
                guard let nextBlockId = nextStep.blockId else {
                    return
                }
                
                guard let nextBlock = layout.block(for: nextBlockId) else {
                    XCTFail("Unable to find block \(nextBlockId)")
                    return
                }
                
                let turnouts = try! layout.turnouts(from: block, to: nextBlock, direction: step.direction!)
                XCTAssertEqual(expectedTurnouts.count, turnouts.count, "Mismatching number of turnouts between \(block) and \(nextBlock)")
                
                for index in 0..<turnouts.count {
                    let expectedTurnout = expectedTurnouts[index]
                    let turnout = turnouts[index]
                    XCTAssertEqual(expectedTurnout.id, turnout.id.uuid)
                    XCTAssertEqual(expectedTurnout.state, turnout.state)
                }
            }
        }
    }
    
}

private extension Layout {
    
    func turnouts(from fromBlock: Block, to nextBlock: Block, direction: Direction) throws -> [Turnout] {
        let transitions = try transitions(from: fromBlock, to: nextBlock, direction: direction)
        var turnouts = [Turnout]()
        for transition in transitions {
            if let turnoutId = transition.b.turnout {
                guard let turnout = turnout(for: turnoutId) else {
                    fatalError("Unable to find turnout \(turnoutId)")
                }
                turnouts.append(turnout)
            }
        }
        return turnouts
    }

}
