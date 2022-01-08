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

class LayoutATests: RootLayoutTests {

    override var layoutID: Identifier<Layout>? {
        return LayoutACreator.id
    }
        
    func testLayout() throws {
        // Assert the expectations before the train circulates
        guard let routeId = train.routeId else {
            XCTFail("No route defined for train \(train)")
            return
        }

        guard let route = layout.route(for: routeId, trainId: train.id) else {
            XCTFail("Unable to find route \(routeId)")
            return
        }
        XCTAssertEqual(4, route.steps.count)
        
        let b1 = route.steps[0]
        let b2 = route.steps[1]
        let b3 = route.steps[2]
        let b4 = route.steps[3]

        XCTAssertNotEqual(b1.blockId, b2.blockId)
        XCTAssertNotEqual(b2.blockId, b3.blockId)
        XCTAssertNotEqual(b3.blockId, b1.blockId)
        XCTAssertEqual(b4.blockId, b1.blockId)

        XCTAssertEqual(b1.blockId, layout.currentBlock(train: train)?.id)
        XCTAssertEqual(b2.blockId, layout.nextBlock(train: train)?.id)

        XCTAssertFalse(route.enabled)
        
        let transitions = try layout.transitions(from: b1.blockId, to: b2.blockId, direction: b1.direction)
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

    func testBlockReserved() throws {
        // Reserve a block with another route to make the train stop
        let b3 = route.steps[2]
        try layout.reserve(block: b3.blockId, withTrain: Train(uuid: "2"), direction: .next)
        
        assert("r1:{r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] <t1> [r2[b3 ≏ ≏ ]] <t0(2,0)> !{r1{b1 ≏ ≏ }}")

        try coordinator.start(routeID: "r1", trainID: "1")

        assert("r1:{r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [r2[b3 ≏ ≏ ]] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
        assert("r1:{r1{b1 ≡ 🚂1 ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [r2[b3 ≏ ≏ ]] <r1<t0(2,0)>> !{r1{b1 ≡ ≏ }}")
        assert("r1:{r1{b1 ≏ ≡ 🚂1 }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [r2[b3 ≏ ≏ ]] <r1<t0(2,0)>> !{r1{b1 ≏ ≡ }}")
        assert("r1:{b1 ≏ ≏ } <t0> [r1[b2 ≡ 🚂1 ≏ ]] <t1> [r2[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        assert("r1:{b1 ≏ ≏ } <t0> [r1[b2 ≏ ≡ 🛑🚂1 ]] <t1> [r2[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        
        // The train re-starts after the block is `unreserved`
        try layout.free(block: b3.blockId)
        assert("r1:{b1 ≏ ≏ } <t0> [r1[b2 ≏ ≡ 🚂1 ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        
        route.enabled = false
        assert("r1:{b1 ≏ ≏ } <t0> [r1[b2 ≏ ≡ 🛑🚂1 ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
    }
    
    func testBlockDisabled() throws {
        // Disable a block to make the train stop
        let b3 = layout.block(for: route.steps[2].blockId)!
        b3.enabled = false
        
        assert("r1:{r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{r1{b1 ≏ ≏ }}")

        try coordinator.start(routeID: "r1", trainID: "1")

        assert("r1:{r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
        assert("r1:{r1{b1 ≡ 🚂1 ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≡ ≏ }}")
        assert("r1:{r1{b1 ≏ ≡ 🚂1 }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≡ }}")
        assert("r1:{b1 ≏ ≏ } <t0> [r1[b2 ≡ 🚂1 ≏ ]] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{b1 ≏ ≏ }")
        assert("r1:{b1 ≏ ≏ } <t0> [r1[b2 ≏ ≡ 🛑🚂1 ]] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{b1 ≏ ≏ }")
        
        // Re-enable b3
        b3.enabled = true
        assert("r1:{b1 ≏ ≏ } <t0> [r1[b2 ≏ ≡ 🚂1 ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        
        route.enabled = false
        assert("r1:{b1 ≏ ≏ } <t0> [r1[b2 ≏ ≡ 🛑🚂1 ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
    }

    func testMoveInsideBlock() throws {
        assert("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{r1{b1 ≏ ≏ }}")
        assert("r1: {r1{b1 🛑🚂1 ≡ ≏ }} <t0> [b2 ≏ ≏ ] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{r1{b1 ≡ ≏ }}")

        try coordinator.start(routeID: "r1", trainID: "1")

        assert("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
        assert("r1: {r1{b1 ≡ 🚂1 ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≡ ≏ }}")
        assert("r1: {r1{b1 ≏ ≡ 🚂1 }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≡ }}")
        assert("r1: {b1 ≏ ≏ } <t0> [r1[b2 ≡ 🚂1 ≏ ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        assert("r1: {b1 ≏ ≏ } <t0> [r1[b2 ≏ ≡ 🚂1 ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        assert("r1: {b1 ≏ ≏ } <t0> [r1[b2 ≏ ≏ 🚂1 ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [b2 ≏ ≏ ] <t1,l> [r1[b3 ≡ 🚂1 ≏ ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
        assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [b2 ≏ ≏ ] <t1,l> [r1[b3 ≏ 🚂1 ≏ ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
        assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [b2 ≏ ≏ ] <t1,l> [r1[b3 ≏ ≡ 🚂1 ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
        assert("r1: {r1{b1 ≏ 🚂1 ≡ }} <t0,l> [b2 ≏ ≏ ] <t1,l> [b3 ≏ ≏ ] <t0(2,0),l> !{r1{b1 ≏ 🚂1 ≡ }}")
        assert("r1: {r1{b1 ≏ 🚂1 ≏ }} <t0,l> [b2 ≏ ≏ ] <t1,l> [b3 ≏ ≏ ] <t0(2,0),l> !{r1{b1 ≏ 🚂1 ≏ }}")
        assert("r1: {r1{b1 🛑🚂1 ≡ ≏ }} <t0,l> [b2 ≏ ≏ ] <t1,l> [b3 ≏ ≏ ] <t0(2,0),l> !{r1{b1 🛑🚂1 ≡ ≏ }}")
    }
    
    func testRouteReverseLoop() throws {
        try layout.free(trainID: layout.trains.first!.id, removeFromLayout: true)
        try layout.prepare(routeID: "r2", trainID: "2")

        assert("r2: {r2{b1 🛑🚂2 ≡ ≏ }} <t0(0,2)> ![b3 ≏ ≏ ] <t1> ![b2 ≏ ≏ ] <t0(1,0)> !{r2{b1 ≡ ≏ }}")
        
        try coordinator.start(routeID: "r2", trainID: "2")
        
        assert("r2: {r2{b1 🚂2 ≏ ≏ }} <r2<t0(0,2),l>> ![r2[b3 ≏ ≏ ]] <t1> ![b2 ≏ ≏ ] <r2<t0(1,0),l>> !{r2{b1 ≏ ≏ }}")
        assert("r2: {r2{b1 ≡ 🚂2 ≏ }} <r2<t0(0,2),l>> ![r2[b3 ≏ ≏ ]] <t1> ![b2 ≏ ≏ ] <r2<t0(1,0),l>> !{r2{b1 ≏ ≏ }}")
        assert("r2: {r2{b1 ≏ ≡ 🚂2 }} <r2<t0(0,2),l>> ![r2[b3 ≏ ≏ ]] <t1> ![b2 ≏ ≏ ] <r2<t0(1,0),l>> !{r2{b1 ≏ ≏ }}")
        assert("r2: {b1 ≏ ≏ } <t0(0,2),l> ![r2[b3 ≏ 🚂2 ≡ ]] <r2<t1,l>> ![r2[b2 ≏ ≏ ]] <t0(1,0),l> !{b1 ≏ ≏ }")
        assert("r2: {b1 ≏ ≏ } <t0(0,2),l> ![r2[b3 🚂2 ≡ ≏ ]] <r2<t1,l>> ![r2[b2 ≏ ≏ ]] <t0(1,0),l> !{b1 ≏ ≏ }")
        assert("r2: {r2{b1 ≏ ≏ }} <r2<t0(0,2)>> ![b3 ≏ ≏ ] <t1,l> ![r2[b2 ≏ 🚂2 ≡ ]] <r2<t0(1,0)>> !{r2{b1 ≏ ≏ }}")
        assert("r2: {r2{b1 ≏ ≏ }} <r2<t0(0,2)>> ![b3 ≏ ≏ ] <t1,l> ![r2[b2 🚂2 ≡ ≏ ]] <r2<t0(1,0)>> !{r2{b1 ≏ ≏ }}")
        assert("r2: {r2{b1 ≏ 🚂2 ≡ }} <t0(0,2)> ![b3 ≏ ≏ ] <t1,l> ![b2 ≏ ≏ ] <t0(1,0)> !{r2{b1 ≏ 🚂2 ≡ }}")
        assert("r2: {r2{b1 🛑🚂2 ≡ ≏ }} <t0(0,2)> ![b3 ≏ ≏ ] <t1,l> ![b2 ≏ ≏ ] <t0(1,0)> !{r2{b1 🛑🚂2 ≡ ≏ }}")
    }
        
    func testTurnoutBetweenBlocks() throws {
        let b2 = layout.block(for: route.steps[1].blockId)!
        let b3 = layout.block(for: route.steps[2].blockId)!

        try layout.setTrain(train.id, toBlock: b2.id, direction: nil)

        XCTAssertNoThrow(try layout.reserve(train: train.id, fromBlock: b2.id, toBlock: b3.id, direction: .next))
        
        try layout.setTrain(train, routeIndex: 1)
        try layout.setTrain(train, toPosition: 1)

        assert("r1: {b1 ≏ ≏ } <t0> [r1[b2 ≏ 🛑🚂1 ≏ ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        
        try coordinator.start(routeID: "r1", trainID: "1")

        assert("r1: {b1 ≏ ≏ } <t0> [r1[b2 ≏ 🚂1 ≏ ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        assert("r1: {b1 ≏ ≏ } <t0> [r1[b2 ≏ ≡ 🚂1 ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [b2 ≏ ≏ ] <t1,l> [r1[b3 ≡ 🚂1  ≏ ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
    }

    func testStrictModeNextBlockFeedback() throws {
        layout.strictRouteFeedbackStrategy = true
        layout.detectUnexpectedFeedback = true
        
        assert("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{r1{b1 ≏ ≏ }}")

        try coordinator.start(routeID: "r1", trainID: "1")

        assert("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
        assert("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
        
        // Train should stop because the next block b2's feedback is triggered but the train is not at the end of block b1
        assert("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≡ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
    }

    func testStrictModeFeedbackTooFar() throws {
        layout.strictRouteFeedbackStrategy = true
        layout.detectUnexpectedFeedback = true
        
        assert("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{r1{b1 ≏ ≏ }}")

        try coordinator.start(routeID: "r1", trainID: "1")

        assert("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
        assert("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")

        // Train does not move because the feedback is not the next one
        assert("r1: {r1{b1 🚂1 ≏ ≡ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
    }

    func testRelaxModeNextModeFeedback() throws {
        layout.strictRouteFeedbackStrategy = false
        layout.detectUnexpectedFeedback = true

        assert("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{r1{b1 ≏ ≏ }}")

        try coordinator.start(routeID: "r1", trainID: "1")

        assert("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
        // The train should continue to the next block when the feedback of the next block is triggered
        assert("r1: {b1 ≏ ≏ } <t0> [r1[b2 ≡ 🚂1 ≏ ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
    }

    func testRelaxModeNextBlockFeedbackTooFar() throws {
        layout.strictRouteFeedbackStrategy = false
        layout.detectUnexpectedFeedback = true

        assert("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{r1{b1 ≏ ≏ }}")

        try coordinator.start(routeID: "r1", trainID: "1")

        assert("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
        // The train should stop because the next block feedback is triggered but it is not the one expected
        // to be triggered given the direction of travel of the train
        assert("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≡ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
    }

    func testRelaxModeNextAndPreviousFeedbacks() throws {
        layout.strictRouteFeedbackStrategy = false
        layout.detectUnexpectedFeedback = true
        
        assert("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{r1{b1 ≏ ≏ }}")

        try coordinator.start(routeID: "r1", trainID: "1")

        assert("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
        
        // Train position should be updated although the feedback is not next to the train but a bit further.
        assert("r1: {r1{b1 ≏ ≡ 🚂1 }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
        assert("r1: {r1{b1 ≡ ≏ 🚂1 }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
    }

}
