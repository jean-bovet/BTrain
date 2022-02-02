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

class ManualRoutingTests: BTTestCase {
        
    func testLayout() throws {
        let layout = LayoutACreator().newLayout()
        let train = layout.trains[0]
        
        try layout.prepare(routeID: layout.routes[0].id, trainID: layout.trains[0].id)
        
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
        let layout = LayoutACreator().newLayout()
        let p = try setup(layout: layout, fromBlockId: "b1", route: layout.routes[0])

        // Reserve a block with another route to make the train stop
        let b3 = layout.block(for: p.route.steps[2].blockId)!
        b3.reserved = .init("2", .next)
        
        try p.assert("r1:{r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] <t1> [r2[b3 ≏ ≏ ]] <t0(2,0)> !{r1{b1 ≏ ≏ }}")

        try p.start(routeID: "r1", trainID: "1")

        try p.assert("r1:{r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [r2[b3 ≏ ≏ ]] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1:{r1{b1 ≡ 🚂1 ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [r2[b3 ≏ ≏ ]] <r1<t0(2,0)>> !{r1{b1 ≡ ≏ }}")
        try p.assert("r1:{r1{b1 ≏ ≡ 🚂1 }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [r2[b3 ≏ ≏ ]] <r1<t0(2,0)>> !{r1{b1 ≏ ≡ }}")
        try p.assert("r1:{b1 ≏ ≏ } <t0> [r1[b2 ≡ 🟨🚂1 ≏ ]] <t1> [r2[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        try p.assert("r1:{b1 ≏ ≏ } <t0> [r1[b2 ≏ ≡ 🛑🚂1 ]] <t1> [r2[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        
        // The train re-starts after the block is `unreserved`
        try layout.free(block: b3.id)
        try p.assert("r1:{b1 ≏ ≏ } <t0> [r1[b2 ≏ ≡ 🚂1 ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        
        try layout.stopTrain(Identifier<Train>(uuid: "1"), completely: true)
        
        try p.assert("r1:{b1 ≏ ≏ } <t0> [r1[b2 ≏ ≡ 🛑🚂1 ]] <t1,l> [b3 ≏ ≏ ] <t0(2,0)> !{b1 ≏ ≏ }")
    }
    
    func testBlockDisabled() throws {
        let layout = LayoutACreator().newLayout()
        let p = try setup(layout: layout, fromBlockId: "b1", route: layout.routes[0])

        // Disable a block to make the train stop
        let b3 = layout.block(for: p.route.steps[2].blockId)!
        b3.enabled = false
        
        try p.assert("r1:{r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{r1{b1 ≏ ≏ }}")

        try p.start(routeID: "r1", trainID: "1")

        try p.assert("r1:{r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1:{r1{b1 ≡ 🚂1 ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≡ ≏ }}")
        try p.assert("r1:{r1{b1 ≏ ≡ 🚂1 }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≡ }}")
        try p.assert("r1:{b1 ≏ ≏ } <t0> [r1[b2 ≡ 🟨🚂1 ≏ ]] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{b1 ≏ ≏ }")
        try p.assert("r1:{b1 ≏ ≏ } <t0> [r1[b2 ≏ ≡ 🛑🚂1 ]] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{b1 ≏ ≏ }")
        
        // Re-enable b3
        b3.enabled = true
        try p.assert("r1:{b1 ≏ ≏ } <t0> [r1[b2 ≏ ≡ 🚂1 ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        
        try layout.stopTrain(Identifier<Train>(uuid: "1"), completely: true)
        
        try p.assert("r1:{b1 ≏ ≏ } <t0> [r1[b2 ≏ ≡ 🛑🚂1 ]] <t1,l> [b3 ≏ ≏ ] <t0(2,0)> !{b1 ≏ ≏ }")
    }

    func testStartNotInRoute() throws {
        let layout = LayoutCCreator().newLayout()
        let p = try setup(layout: layout, fromBlockId: "b5", route: layout.routes[0])

        try p.assert("r1: {b1 ≏ ≏ } <t0> [b2 ≏ ≏ ] {b3 ≏ ≏ } <t1> [b4 ≏ ≏] {b1 ≏ ≏ }")
        
        XCTAssertThrowsError(try p.start(routeID: "r1", trainID: "1")) { error in
            guard let layoutError = error as? LayoutError else {
                XCTFail()
                return
            }
            
            guard case .trainNotFoundInRoute(train: _, route: _) = layoutError else {
                XCTFail()
                return
            }
        }
    }
    
    func testStartInRouteButReversedDirection() throws {
        let layout = LayoutCCreator().newLayout()
        
        var p = try setup(layout: layout, fromBlockId: "b1", direction: .previous, route: layout.routes[0])

        try p.assert("r1: {r1{b1 ≏ ≏ 🛑🚂1 }} <t0> [b2 ≏ ≏ ] {b3 ≏ ≏ }} <t1> [b4 ≏ ≏] {r1{b1 ≏ ≏ 🛑🚂1 }}")
                
        XCTAssertThrowsError(try p.start(routeID: "r1", trainID: "1")) { error in
            guard let layoutError = error as? LayoutError else {
                XCTFail()
                return
            }
            
            guard case .trainNotFoundInRoute(train: _, route: _) = layoutError else {
                XCTFail()
                return
            }
        }
        
        p = try setup(layout: layout, fromBlockId: "b1", direction: .next, route: layout.routes[0])

        try p.assert("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] {b3 ≏ ≏ }} <t1> [b4 ≏ ≏] {r1{b1 🛑🚂1 ≏ ≏ }}")
        try p.start(routeID: "r1", trainID: "1")
    }

    func testMoveInsideBlock() throws {
        let layout = LayoutACreator().newLayout()
        let p = try setup(layout: layout, fromBlockId: "b1", route: layout.routes[0])

        try p.assert("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 🛑🚂1 ≡ ≏ }} <t0> [b2 ≏ ≏ ] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{r1{b1 ≡ ≏ }}")
        try p.assert("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{r1{b1 ≏ ≏ }}")

        try p.start(routeID: "r1", trainID: "1")

        try p.assert("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≡ 🚂1 ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≡ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≡ 🚂1 }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≡ }}")
        try p.assert("r1: {b1 ≏ ≏ } <t0> [r1[b2 ≡ 🚂1 ≏ ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        try p.assert("r1: {b1 ≏ ≏ } <t0> [r1[b2 ≏ ≡ 🚂1 ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        try p.assert("r1: {b1 ≏ ≏ } <t0> [r1[b2 ≏ ≏ 🚂1 ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [b2 ≏ ≏ ] <t1,l> [r1[b3 ≡ 🚂1 ≏ ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [b2 ≏ ≏ ] <t1,l> [r1[b3 ≏ 🚂1 ≏ ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [b2 ≏ ≏ ] <t1,l> [r1[b3 ≏ ≡ 🚂1 ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ 🟨🚂1 ≡ }} <t0,l> [b2 ≏ ≏ ] <t1,l> [b3 ≏ ≏ ] <t0(2,0),l> !{r1{b1 ≡ 🟨🚂1 ≏ }}")
        try p.assert("r1: {r1{b1 ≏ 🟨🚂1 ≏ }} <t0,l> [b2 ≏ ≏ ] <t1,l> [b3 ≏ ≏ ] <t0(2,0),l> !{r1{b1 ≏ 🟨🚂1 ≏ }}")
        try p.assert("r1: {r1{b1 🛑🚂1 ≡ ≏ }} <t0,l> [b2 ≏ ≏ ] <t1,l> [b3 ≏ ≏ ] <t0(2,0),l> !{r1{b1 ≏ ≡ 🛑🚂1 }}")
    }
    
    func testMoveWith2LeadingReservation() throws {
        let layout = LayoutACreator().newLayout()
        let t1 = layout.trains[0]
        t1.maxNumberOfLeadingReservedBlocks = 2
        
        let p = try setup(layout: layout, fromBlockId: "b1", route: layout.routes[0])

        try p.assert("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{r1{b1 ≏ ≏ }}")

        try p.start(routeID: "r1", trainID: "1")

        try p.assert("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≡ 🚂1 ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <r1<t0(2,0)>> !{r1{b1 ≡ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≡ 🚂1 }} <r1<t0>> [r1[b2 ≏ ≏ ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <r1<t0(2,0)>> !{r1{b1 ≏ ≡ }}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [r1[b2 ≡ 🚂1 ≏ ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏}}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [r1[b2 ≏ ≡ 🚂1 ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [r1[b2 ≏ ≏ 🚂1 ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [b2 ≏ ≏ ] <t1,l> [r1[b3 ≡ 🚂1 ≏ ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [b2 ≏ ≏ ] <t1,l> [r1[b3 ≏ 🚂1 ≏ ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [b2 ≏ ≏ ] <t1,l> [r1[b3 ≏ ≡ 🚂1 ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ 🟨🚂1 ≡ }} <t0,l> [b2 ≏ ≏ ] <t1,l> [b3 ≏ ≏ ] <t0(2,0),l> !{r1{b1 ≏ 🟨🚂1 ≡ }}")
        try p.assert("r1: {r1{b1 ≏ 🟨🚂1 ≏ }} <t0,l> [b2 ≏ ≏ ] <t1,l> [b3 ≏ ≏ ] <t0(2,0),l> !{r1{b1 ≏ 🟨🚂1 ≏ }}")
        try p.assert("r1: {r1{b1 🛑🚂1 ≡ ≏ }} <t0,l> [b2 ≏ ≏ ] <t1,l> [b3 ≏ ≏ ] <t0(2,0),l> !{r1{b1 ≏ ≡ 🛑🚂1 }}")
    }

    func testMoveWith2LeadingReservationWithLoop() throws {
        let layout = LayoutBCreator().newLayout()
        let p = try setup(layout: layout, fromBlockId: "b1", route: layout.routes[0])
        
        let t1 = layout.trains[0]
        t1.maxNumberOfLeadingReservedBlocks = 2
        
        layout.strictRouteFeedbackStrategy = false

        try p.assert("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t1{ds2}> [b2 ≏ ≏ ] [b3 ≏ ≏ ] <t1{ds2}(2,3)> [b4 ≏ ≏ ] {r1{b1 🛑🚂1 ≏ ≏ }}")

        try p.start(routeID: "r1", trainID: "1")

        try p.assert("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t1{ds2},s01>> [r1[b2 ≏ ≏ ]] [r1[b3 ≏ ≏ ]] <r1<t1{ds2}(2,3),s01>> [b4 ≏ ≏ ] {r1{b1 🚂1 ≏ ≏ }}")
        try p.assert("r1: {b1 ≏ ≏ } <r1<t1{ds2},s23>> [r1[b2 ≡ 🚂1 ≏ ]] [r1[b3 ≏ ≏ ]] <r1<t1{ds2}(2,3),s23>> [r1[b4 ≏ ≏ ]] {b1 ≏ ≏ }")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t1{ds2},s23>> [b2 ≏ ≏ ] [r1[b3 ≡ 🚂1 ≏ ]] <r1<t1{ds2}(2,3),s23>> [r1[b4 ≏ ≏ ]] {r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <t1{ds2},s23> [b2 ≏ ≏ ] [b3 ≏ ≏ ] <t1{ds2}(2,3),s23> [r1[b4 ≡ 🚂1 ≏ ]] {r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≡ 🟨🚂1 ≏ }} <t1{ds2},s23> [b2 ≏ ≏ ] [b3 ≏ ≏ ] <t1{ds2}(2,3),s23> [b4 ≏ ≏ ] {r1{b1 ≡ 🟨🚂1 ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≡ 🛑🚂1 }} <t1{ds2},s23> [b2 ≏ ≏ ] [b3 ≏ ≏ ] <t1{ds2}(2,3),s23> [b4 ≏ ≏ ] {r1{b1 ≏ ≡ 🛑🚂1 }}")
    }

    func testMoveWith3LeadingReservationWithLoop() throws {
        let layout = LayoutBCreator().newLayout()
        let p = try setup(layout: layout, fromBlockId: "b1", route: layout.routes[0])
        
        let t1 = layout.trains[0]
        t1.maxNumberOfLeadingReservedBlocks = 3
        
        layout.strictRouteFeedbackStrategy = false

        try p.assert("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t1{ds2}> [b2 ≏ ≏ ] [b3 ≏ ≏ ] <t1{ds2}(2,3)> [b4 ≏ ≏ ] {r1{b1 🛑🚂1 ≏ ≏ }}")

        try p.start(routeID: "r1", trainID: "1")

        // b4 is not reserved because the turnout t1 is already reserved for b1->b2.
        try p.assert("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t1{ds2},s01>> [r1[b2 ≏ ≏ ]] [r1[b3 ≏ ≏ ]] <r1<t1{ds2}(2,3),s01>> [b4 ≏ ≏ ] {r1{b1 🚂1 ≏ ≏ }}")
        
        // Now that the train is in b2, the turnout t1 is free and the leading blocks can be reserved until b1, including b4.
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t1{ds2},s23>> [r1[b2 ≡ 🚂1 ≏ ]] [r1[b3 ≏ ≏ ]] <r1<t1{ds2}(2,3),s23>> [r1[b4 ≏ ≏ ]] {r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t1{ds2},s23>> [b2 ≏ ≏ ] [r1[b3 ≡ 🚂1 ≏ ]] <r1<t1{ds2}(2,3),s23>> [r1[b4 ≏ ≏ ]] {r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <t1{ds2},s23> [b2 ≏ ≏ ] [b3 ≏ ≏ ] <t1{ds2}(2,3),s23> [r1[b4 ≡ 🚂1 ≏ ]] {r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≡ 🟨🚂1 ≏ }} <t1{ds2},s23> [b2 ≏ ≏ ] [b3 ≏ ≏ ] <t1{ds2}(2,3),s23> [b4 ≏ ≏ ] {r1{b1 ≡ 🟨🚂1 ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≡ 🛑🚂1 }} <t1{ds2},s23> [b2 ≏ ≏ ] [b3 ≏ ≏ ] <t1{ds2}(2,3),s23> [b4 ≏ ≏ ] {r1{b1 ≏ ≡ 🛑🚂1 }}")
    }

    func testMoveWith3LeadingReservation() throws {
        let layout = LayoutACreator().newLayout()
        let t1 = layout.trains[0]
        t1.maxNumberOfLeadingReservedBlocks = 3
        
        let p = try setup(layout: layout, fromBlockId: "b1", route: layout.routes[0])

        try p.assert("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{r1{b1 ≏ ≏ }}")

        try p.start(routeID: "r1", trainID: "1")

        try p.assert("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≡ 🚂1 ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <r1<t0(2,0)>> !{r1{b1 ≡ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≡ 🚂1 }} <r1<t0>> [r1[b2 ≏ ≏ ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <r1<t0(2,0)>> !{r1{b1 ≏ ≡ }}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [r1[b2 ≡ 🚂1 ≏ ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏}}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [r1[b2 ≏ ≡ 🚂1 ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [r1[b2 ≏ ≏ 🚂1 ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [b2 ≏ ≏ ] <t1,l> [r1[b3 ≡ 🚂1 ≏ ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [b2 ≏ ≏ ] <t1,l> [r1[b3 ≏ 🚂1 ≏ ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [b2 ≏ ≏ ] <t1,l> [r1[b3 ≏ ≡ 🚂1 ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ 🟨🚂1 ≡ }} <t0,l> [b2 ≏ ≏ ] <t1,l> [b3 ≏ ≏ ] <t0(2,0),l> !{r1{b1 ≡ 🟨🚂1 ≏ }}")
        try p.assert("r1: {r1{b1 ≏ 🟨🚂1 ≏ }} <t0,l> [b2 ≏ ≏ ] <t1,l> [b3 ≏ ≏ ] <t0(2,0),l> !{r1{b1 ≏ 🟨🚂1 ≏ }}")
        try p.assert("r1: {r1{b1 🛑🚂1 ≡ ≏ }} <t0,l> [b2 ≏ ≏ ] <t1,l> [b3 ≏ ≏ ] <t0(2,0),l> !{r1{b1 ≏ ≡ 🛑🚂1 }}")
    }

    //       ┌─────────┐                              ┌─────────┐
    //    ┌──│ Block 2 │◀────┐         ┌─────────────▶│ Block 4 │──┐
    //    │  └─────────┘     │         │              └─────────┘  │
    //    │                  │         │                           │
    //    │                  │                                     │
    //    │                  └─────Turnout1 ◀───┐                  │
    //    │                                     │                  │
    //    │                            ▲        │                  │
    //    │  ┌─────────┐               │        │     ┌─────────┐  │
    //    └─▶│ Block 3 │───────────────┘        └─────│ Block 1 │◀─┘
    //       └─────────┘                              └─────────┘
    func testMoveWith1TrailingReservationNoFeedbacks() throws {
        let layout = LayoutBCreator().newLayout()
        
        // Let's only define block length and omit feedback distances
        for block in layout.blocks {
            block.length = 100
        }

        let t1 = layout.trains[0]
        t1.length = 150 // That way, the train always needs one trailing block reserved to account for its length
        t1.maxNumberOfLeadingReservedBlocks = 1

        let p = try setup(layout: layout, fromBlockId: "b1", position: .end, route: layout.routes[0])
        p.asserter.assertBlockParts = true
        
        try p.assert("r1: {r1{b1 💺1 ≏ 💺1 ≏ 🛑🚂1 }} <t1{ds2}> [b2 ≏ ≏ ] [b3 ≏ ≏ ] <t1{ds2}(2,3)> [r1[b4 💺1 ≏ 💺1 ≏ 💺1 ]] {r1{b1 💺1 ≏ 💺1 ≏ 🛑🚂1}}")

        try p.start(routeID: "r1", trainID: "1")

        try p.assert("r1: {r1{b1 💺1 ≏ 💺1 ≏ 🚂1 }} <r1<t1{ds2},s01>> [r1[b2 ≏ ≏ ]] [b3 ≏ ≏ ] <r1<t1{ds2}(2,3),s01>> [r1[b4 💺1 ≏ 💺1 ≏ 💺1 ]] {r1{b1 💺1 ≏ 💺1 ≏ 🚂1}}")
        try p.assert("r1: {r1{b1 💺1 ≏ 💺1 ≏ 💺1 }} <r1<t1{ds2},s01>> [r1[b2 💺1 ≡ 🚂1 ≏ ]] [r1[b3 ≏ ≏ ]] <r1<t1{ds2}(2,3),s01>> [b4 ≏ ≏ ] {r1{b1 💺1 ≏ 💺1 ≏ 💺1}}")
        try p.assert("r1: {r1{b1 💺1 ≏ 💺1 ≏ 💺1 }} <r1<t1{ds2},s01>> [r1[b2 💺1 ≏ 💺1 ≡ 🚂1 ]] [r1[b3 ≏ ≏ ]] <r1<t1{ds2}(2,3),s01>> [b4 ≏ ≏ ] {r1{b1 💺1 ≏ 💺1 ≏ 💺1}}")
        try p.assert("r1: {b1 ≏ ≏ } <r1<t1{ds2},s23>> [r1[b2 💺1 ≏ 💺1 ≏ 💺1 ]] [r1[b3 💺1 ≡ 🚂1 ≏ ]] <r1<t1{ds2}(2,3),s23>> [r1[b4 ≏ ≏ ]] {b1 ≏ ≏ }")
        try p.assert("r1: {b1 ≏ ≏ } <r1<t1{ds2},s23>> [r1[b2 💺1 ≏ 💺1 ≏ 💺1 ]] [r1[b3 💺1 ≏ 💺1 ≡ 🚂1 ]] <r1<t1{ds2}(2,3),s23>> [r1[b4 ≏ ≏ ]] {b1 ≏ ≏ }")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t1{ds2},s23>> [b2 ≏ ≏ ] [r1[b3 💺1 ≏ 💺1 ≏ 💺1 ]] <r1<t1{ds2}(2,3),s23>> [r1[b4 💺1 ≡ 🚂1 ≏ ]] {r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t1{ds2},s23>> [b2 ≏ ≏ ] [r1[b3 💺1 ≏ 💺1 ≏ 💺1 ]] <r1<t1{ds2}(2,3),s23>> [r1[b4 💺1 ≏ 💺1 ≡ 🚂1 ]] {r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 💺1 ≡ 🟨🚂1 ≏ }} <t1{ds2},s23> [b2 ≏ ≏ ] [b3 ≏ ≏ ] <t1{ds2}(2,3),s23> [r1[b4 💺1 ≏ 💺1 ≏ 💺1 ]] {r1{b1 💺1 ≡ 🟨🚂1 ≏ }}")
        try p.assert("r1: {r1{b1 💺1 ≏ 💺1 ≡ 🛑🚂1 }} <t1{ds2},s23> [b2 ≏ ≏ ] [b3 ≏ ≏ ] <t1{ds2}(2,3),s23> [r1[b4 💺1 ≏ 💺1 ≏ 💺1 ]] {r1{b1 💺1 ≏ 💺1 ≡ 🛑🚂1 }}")
    }

    func testMoveWith1TrailingReservationWithFeedbacks() throws {
        let layout = LayoutBCreator().newLayout()
        
        for block in layout.blocks {
            block.length = 100
            block.feedbacks[0].distance = 20
            block.feedbacks[1].distance = 100 - 20
        }

        let t1 = layout.trains[0]
        t1.length = 140 // That way, the train always needs one trailing block reserved to account for its length
        t1.maxNumberOfLeadingReservedBlocks = 1

        let p = try setup(layout: layout, fromBlockId: "b1", position: .end, route: layout.routes[0])
        p.asserter.assertBlockParts = true
        
        // b1: { w20 | w60 | >20 } b2: [ 20 | 60 | 20 ] b3: [ 20 | 60 | 20 ] b4: [ 20 | w60 | w20 ]
        try p.assert("r1: {r1{b1 💺1 ≏ 💺1 ≏ 🛑🚂1 }} <t1{ds2}> [b2 ≏ ≏ ] [b3 ≏ ≏ ] <t1{ds2}(2,3)> [r1[b4 ≏ 💺1 ≏ 💺1 ]] {r1{b1 💺1 ≏ 💺1 ≏ 🛑🚂1}}")

        try p.start(routeID: "r1", trainID: "1")

        // b1: { w20 | w60 | >20 } b2: [ 20 | 60 | 20 ] b3: [ 20 | 60 | 20 ] b4: [ 20 | w60 | w20 ]
        try p.assert("r1: {r1{b1 💺1 ≏ 💺1 ≏ 🚂1 }} <r1<t1{ds2},s01>> [r1[b2 ≏ ≏ ]] [b3 ≏ ≏ ] <r1<t1{ds2}(2,3),s01>> [r1[b4 ≏ 💺1 ≏ 💺1 ]] {r1{b1 💺1 ≏ 💺1 ≏ 🚂1}}")
        
        // b1: { w20 | w60 | w20 } b2: [ w20 | >60 | 20 ] b3: [ 20 | 60 | 20 ] b4: [ 20 | 60 | w20 ]
        try p.assert("r1: {r1{b1 💺1 ≏ 💺1 ≏ 💺1 }} <r1<t1{ds2},s01>> [r1[b2 💺1 ≡ 🚂1 ≏ ]] [r1[b3 ≏ ≏ ]] <r1<t1{ds2}(2,3),s01>> [r1[b4 ≏ ≏ 💺1 ]] {r1{b1 💺1 ≏ 💺1 ≏ 💺1}}")
        
        // b1: { 20 | w60 | w20 } b2: [ w20 | w60 | >20 ] b3: [ 20 | 60 | 20 ] b4: [ 20 | 60 | 20 ]
        try p.assert("r1: {r1{b1 ≏ 💺1 ≏ 💺1 }} <r1<t1{ds2},s01>> [r1[b2 💺1 ≏ 💺1 ≡ 🚂1 ]] [r1[b3 ≏ ≏ ]] <r1<t1{ds2}(2,3),s01>> [b4 ≏ ≏ ] {r1{b1 ≏ 💺1 ≏ 💺1}}")
        
        // b1: { 20 | 60 | w20 } b2: [ w20 | w60 | w20 ] b3: [ w20 | >60 | 20 ] b4: [ 20 | 60 | 20 ]
        // Note: train is slowing down to stop because b4 cannot be reserved it because the trail of the train still occupies the turnout
        try p.assert("r1: {r1{b1 ≏ ≏ 💺1 }} <r1<t1{ds2},s01>> [r1[b2 💺1 ≏ 💺1 ≏ 💺1 ]] [r1[b3 💺1 ≡ 🟨🚂1 ≏ ]] <r1<t1{ds2}(2,3),s01>> [b4 ≏ ≏ ] {r1{b1 ≏ ≏ 💺1 }}")
        
        // b1: { 20 | 60 | 20 } b2: [ 20 | w60 | w20 ] b3: [ w20 | w60 | >20 ] b4: [ 20 | 60 | 20 ]
        try p.assert("r1: {b1 ≏ ≏ } <t1{ds2},s01> [r1[b2 ≏ 💺1 ≏ 💺1 ]] [r1[b3 💺1 ≏ 💺1 ≡ 🛑🚂1 ]] <t1{ds2}(2,3),s01> [b4 ≏ ≏ ] {b1 ≏ ≏ }")
        try p.assert("r1: {b1 ≏ ≏ } <r1<t1{ds2},s23>> [r1[b2 ≏ 💺1 ≏ 💺1 ]] [r1[b3 💺1 ≏ 💺1 ≏ 🚂1 ]] <r1<t1{ds2}(2,3),s23>> [r1[b4 ≏ ≏ ]] {b1 ≏ ≏ }")
        
        // b1: { 20 | 60 | 20 } b2: [ 20 | 60 | w20 ] b3: [ w20 | w60 | w20 ] b4: [ w20 | >60 | 20 ]
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t1{ds2},s23>> [r1[b2 ≏ ≏ 💺1 ]] [r1[b3 💺1 ≏ 💺1 ≏ 💺1 ]] <r1<t1{ds2}(2,3),s23>> [r1[b4 💺1 ≡ 🚂1 ≏ ]] {r1{b1 ≏ ≏ }}")
        
        // b1: { 20 | 60 | 20 } b2: [ 20 | 60 | w20 ] b3: [ w20 | w60 | w20 ] b4: [ w20 | >60 | 20 ]
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t1{ds2},s23>> [b2 ≏ ≏ ] [r1[b3 ≏ 💺1 ≏ 💺1 ]] <r1<t1{ds2}(2,3),s23>> [r1[b4 💺1 ≏ 💺1 ≡ 🚂1 ]] {r1{b1 ≏ ≏ }}")
        
        // b2: [ 20 | 60 | w20 ] b3: [ 20 | 60 | w20 ] b4: [ w20 | w60 | w20 ] b1: { w20 | >60 | 20 }
        try p.assert("r1: {r1{b1 💺1 ≡ 🟨🚂1 ≏ }} <r1<t1{ds2},s23>> [b2 ≏ ≏ ] [r1[b3 ≏ ≏ 💺1 ]] <r1<t1{ds2}(2,3),s23>> [r1[b4 💺1 ≏ 💺1 ≏ 💺1 ]] {r1{b1 💺1 ≡ 🟨🚂1 ≏ }}")

        // b2: [ 20 | 60 | w20 ] b3: [ 20 | 60 | 20 ] b4: [ 20 | w60 | w20 ] b1: { w20 | w60 | >20 }
        try p.assert("r1: {r1{b1 💺1 ≏ 💺1 ≡ 🛑🚂1 }} <t1{ds2},s23> [b2 ≏ ≏ ] [b3 ≏ ≏ ] <t1{ds2}(2,3),s23> [r1[b4 ≏ 💺1 ≏ 💺1 ]] {r1{b1 💺1 ≏ 💺1 ≡ 🛑🚂1 }}")
    }

    func testRouteReverseLoop() throws {
        let layout = LayoutACreator().newLayout()
        let p = try setup(layout: layout, fromBlockId: "b1", route: layout.routes[0])

        try layout.remove(trainID: layout.trains.first!.id)
        try layout.prepare(routeID: "r2", trainID: "2")

        try p.assert("r2: {r2{b1 🛑🚂2 ≡ ≏ }} <t0(0,2)> ![b3 ≏ ≏ ] <t1> ![b2 ≏ ≏ ] <t0(1,0)> !{r2{b1 ≡ ≏ }}")
        try p.assert("r2: {r2{b1 🛑🚂2 ≏ ≏ }} <t0(0,2)> ![b3 ≏ ≏ ] <t1> ![b2 ≏ ≏ ] <t0(1,0)> !{r2{b1 ≡ ≏ }}")

        try p.start(routeID: "r2", trainID: "2")
        
        try p.assert("r2: {r2{b1 🚂2 ≏ ≏ }} <r2<t0(0,2),l>> ![r2[b3 ≏ ≏ ]] <t1> ![b2 ≏ ≏ ] <r2<t0(1,0),l>> !{r2{b1 ≏ ≏ }}")
        try p.assert("r2: {r2{b1 ≡ 🚂2 ≏ }} <r2<t0(0,2),l>> ![r2[b3 ≏ ≏ ]] <t1> ![b2 ≏ ≏ ] <r2<t0(1,0),l>> !{r2{b1 ≏ ≏ }}")
        try p.assert("r2: {r2{b1 ≏ ≡ 🚂2 }} <r2<t0(0,2),l>> ![r2[b3 ≏ ≏ ]] <t1> ![b2 ≏ ≏ ] <r2<t0(1,0),l>> !{r2{b1 ≏ ≏ }}")
        try p.assert("r2: {b1 ≏ ≏ } <t0(0,2),l> ![r2[b3 ≡ 🚂2 ≏ ]] <r2<t1,l>> ![r2[b2 ≏ ≏ ]] <t0(1,0),l> !{b1 ≏ ≏ }")
        try p.assert("r2: {b1 ≏ ≏ } <t0(0,2),l> ![r2[b3 ≏ ≡ 🚂2 ]] <r2<t1,l>> ![r2[b2 ≏ ≏ ]] <t0(1,0),l> !{b1 ≏ ≏ }")
        try p.assert("r2: {r2{b1 ≏ ≏ }} <r2<t0(0,2)>> ![b3 ≏ ≏ ] <t1,l> ![r2[b2 ≡ 🚂2 ≏ ]] <r2<t0(1,0)>> !{r2{b1 ≏ ≏ }}")
        try p.assert("r2: {r2{b1 ≏ ≏ }} <r2<t0(0,2)>> ![b3 ≏ ≏ ] <t1,l> ![r2[b2 ≏ ≡ 🚂2 ]] <r2<t0(1,0)>> !{r2{b1 ≏ ≏ }}")
        try p.assert("r2: {r2{b1 ≏ 🟨🚂2 ≡ }} <t0(0,2)> ![b3 ≏ ≏ ] <t1,l> ![b2 ≏ ≏ ] <t0(1,0)> !{r2{b1 ≡ 🟨🚂2 ≏ }}")
        try p.assert("r2: {r2{b1 🛑🚂2 ≡ ≏ }} <t0(0,2)> ![b3 ≏ ≏ ] <t1,l> ![b2 ≏ ≏ ] <t0(1,0)> !{r2{b1 ≏ ≡ 🛑🚂2 }}")
    }
        
    func testTurnoutBetweenBlocks() throws {
        let layout = LayoutACreator().newLayout()
        let p = try setup(layout: layout, fromBlockId: "b1", route: layout.routes[0])
        let route = p.route
        let train = p.train
        
        let b2 = layout.block(for: route.steps[1].blockId)!
        let b3 = layout.block(for: route.steps[2].blockId)!

        try layout.remove(trainID: train.id)
        try layout.setTrainToBlock(train.id, b2.id, direction: .next)
        
        try layout.setTrainRouteStepIndex(train, 1)
        try layout.setTrainPosition(train, 1)

        XCTAssertNoThrow(try layout.reserve(trainId: train.id, fromBlock: b2.id, toBlock: b3.id, direction: .next))

        try p.assert("r1: {b1 ≏ ≏ } <t0> [r1[b2 ≏ 🛑🚂1 ≏ ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        
        try p.start(routeID: "r1", trainID: "1")

        try p.assert("r1: {b1 ≏ ≏ } <t0> [r1[b2 ≏ 🚂1 ≏ ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        try p.assert("r1: {b1 ≏ ≏ } <t0> [r1[b2 ≏ ≡ 🚂1 ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [b2 ≏ ≏ ] <t1,l> [r1[b3 ≡ 🚂1  ≏ ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
    }

    func testStrictModeNextBlockFeedback() throws {
        let layout = LayoutACreator().newLayout()
        let p = try setup(layout: layout, fromBlockId: "b1", route: layout.routes[0])

        layout.strictRouteFeedbackStrategy = true
        layout.detectUnexpectedFeedback = true
        
        try p.assert("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{r1{b1 ≏ ≏ }}")

        try p.start(routeID: "r1", trainID: "1")

        try p.assert("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
        
        // Train should stop because the next block b2's feedback is triggered but the train is not at the end of block b1
        try p.assert("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≡ ≏ ] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{r1{b1 ≏ ≏ }}")
    }

    func testStrictModeFeedbackTooFar() throws {
        let layout = LayoutACreator().newLayout()
        let p = try setup(layout: layout, fromBlockId: "b1", route: layout.routes[0])

        layout.strictRouteFeedbackStrategy = true
        layout.detectUnexpectedFeedback = true
        
        try p.assert("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{r1{b1 ≏ ≏ }}")

        try p.start(routeID: "r1", trainID: "1")

        try p.assert("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")

        // Train does not move because the feedback is not the next one
        try p.assert("r1: {r1{b1 🚂1 ≏ ≡ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
    }

    func testRelaxModeNextModeFeedback() throws {
        let layout = LayoutACreator().newLayout()
        let p = try setup(layout: layout, fromBlockId: "b1", route: layout.routes[0])

        layout.strictRouteFeedbackStrategy = false
        layout.detectUnexpectedFeedback = true

        try p.assert("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{r1{b1 ≏ ≏ }}")

        try p.start(routeID: "r1", trainID: "1")

        try p.assert("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
        // The train should continue to the next block when the feedback of the next block is triggered
        try p.assert("r1: {b1 ≏ ≏ } <t0> [r1[b2 ≡ 🚂1 ≏ ]] <r1<t1,l>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
    }

    func testRelaxModeNextBlockFeedbackTooFar() throws {
        let layout = LayoutACreator().newLayout()
        let p = try setup(layout: layout, fromBlockId: "b1", route: layout.routes[0])

        layout.strictRouteFeedbackStrategy = false
        layout.detectUnexpectedFeedback = true

        try p.assert("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{r1{b1 ≏ ≏ }}")

        try p.start(routeID: "r1", trainID: "1")

        try p.assert("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
        // The train should stop because the next block feedback is triggered but it is not the one expected
        // to be triggered given the direction of travel of the train
        try p.assert("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≡ ] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{r1{b1 ≏ ≏ }}")
    }

    func testRelaxModeNextAndPreviousFeedbacks() throws {
        let layout = LayoutACreator().newLayout()
        let p = try setup(layout: layout, fromBlockId: "b1", route: layout.routes[0])

        layout.strictRouteFeedbackStrategy = false
        layout.detectUnexpectedFeedback = true
        
        try p.assert("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] <t1> [b3 ≏ ≏ ] <t0(2,0)> !{r1{b1 ≏ ≏ }}")

        try p.start(routeID: "r1", trainID: "1")

        try p.assert("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
        
        // Train position should be updated although the feedback is not next to the train but a bit further.
        try p.assert("r1: {r1{b1 ≏ ≡ 🚂1 }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≡ ≏ 🚂1 }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
    }

    func testNextBlockFeedbackHandling() throws {
        let layout = LayoutCCreator().newLayout()
        
        try layout.prepare(routeID: "r1", trainID: "1")
        try layout.prepare(routeID: "r3", trainID: "2")
        
        let p = try setup(layout: layout, fromBlockId: "b1", route: layout.routes[0])
        
        layout.strictRouteFeedbackStrategy = false
        
        try p.assert2("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] {r2{b3 🛑🚂2 ≏ ≏ }} <t1> [b4 ≏ ≏] {r1{b1 🛑🚂1 ≏ ≏ }}",
                      "r3: {r2{b3 🛑🚂2 ≏ ≏ }} <t1(0,2)> [b5 ≏ ≏ ] <t0(2,0)> !{r1{b1 ≏ ≏ 🛑🚂1 }}")
        
        try p.start(routeID: "r3", trainID: "2")
        
        try p.assert2("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] {r2{b3 🚂2 ≏ ≏ }} <r2<t1,r>> [b4 ≏ ≏] {r1{b1 🛑🚂1 ≏ ≏ }}",
                      "r3: {r2{b3 🚂2 ≏ ≏ }} <r2<t1(0,2),r>> [r2[b5 ≏ ≏ ]] <t0(2,0)> !{r1{b1 ≏ ≏ 🛑🚂1 }}")
        
        try p.assert2("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] {b3 ≏ ≏ } <t1,r> [b4 ≏ ≏] {r1{b1 🛑🚂1 ≏ ≏ }}",
                      "r3: {b3 ≏ ≏ } <t1(0,2),r> [r2[b5 ≡ 🟨🚂2 ≏ ]] <t0(2,0)> !{r1{b1 ≏ ≏ 🛑🚂1 }}")
        
        try p.start(routeID: "r1", trainID: "1")
        
        try p.assert2("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] {b3 ≏ ≏ } <t1,r> [b4 ≏ ≏] {r1{b1 🚂1 ≏ ≏ }}",
                      "r3: {b3 ≏ ≏ } <t1(0,2),r> [r2[b5 ≏ 🟨🚂2 ≏ ]] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ 🚂1 }}")
        
        try p.assert2("r1: {r1{b1 ≡ 🚂1 ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] {b3 ≏ ≏ } <t1,r> [b4 ≏ ≏] {r1{b1 ≡ 🚂1 ≏ }}",
                      "r3: {b3 ≏ ≏ } <t1(0,2),r> [r2[b5 ≏ 🟨🚂2 ≏ ]] <r1<t0(2,0)>> !{r1{b1 ≏ 🚂1 ≡ }}")
        
        // Note: the last feedback of block b1 is activated which moves train 1 within b1. However, this feedback
        // is also used to move train 2 to block b1 but in this situation it should be ignored for train 2 because
        // block b1 is not free.
        try p.assert2("r1: {r1{b1 ≏ ≡ 🚂1 }} <r1<t0>> [r1[b2 ≏ ≏ ]] {b3 ≏ ≏ } <t1,r> [b4 ≏ ≏] {r1{b1 ≏ ≡ 🚂1 }}",
                      "r3: {b3 ≏ ≏ } <t1(0,2),r> [r2[b5 ≏ 🟨🚂2 ≏ ]] <r1<t0(2,0)>> !{r1{b1 🚂1 ≡ ≏ }}")
        
        try p.assert2("r1: {r1{b1 ≏ ≏ 🚂1 }} <r1<t0>> [r1[b2 ≏ ≏ ]] {b3 ≏ ≏ } <t1,r> [b4 ≏ ≏] {r1{b1 ≏ ≏ 🚂1 }}",
                      "r3: {b3 ≏ ≏ } <t1(0,2),r> [r2[b5 ≏ 🟨🚂2 ≏ ]] <r1<t0(2,0)>> !{r1{b1 🚂1 ≏ ≏ }}")
        
        // Train 1 moves to b2
        try p.assert2("r1: {r2{b1 ≏ ≏ }} <r2<t0,r>> [r1[b2 ≡ 🚂1 ≏ ]] {r1{b3 ≏ ≏ }} <t1,r> [b4 ≏ ≏] {b1 ≏ ≏ }",
                      "r3: {b3 ≏ ≏ } <t1(0,2),r> [r2[b5 ≏ 🚂2 ≏ ]] <r2<t0(2,0),r>> !{r2{b1 ≏ ≏ }}")
        
        // Train 2 moves to the end of block b5
        try p.assert2("r1: {r2{b1 ≏ ≏ }} <r2<t0,r>> [r1[b2 ≡ 🚂1 ≏ ]] {r1{b3 ≏ ≏ }} <t1,r> [b4 ≏ ≏] {b1 ≏ ≏ }",
                      "r3: {b3 ≏ ≏ } <t1(0,2),r> [r2[b5 ≏ ≡ 🚂2 ]] <r2<t0(2,0),r>> !{r2{b1 ≏ ≏ }}")
        
        // Now train 2 is starting again after reserving block b1 for itself
        try p.assert2("r1: {r2{b1 ≏ ≏ }} <r2<t0,r>> [r1[b2 ≏ 🚂1 ≏ ]] {r1{b3 ≏ ≏ }} <t1,r> [b4 ≏ ≏] {r2{b1 ≏ ≏ }}",
                      "r3: {b3 ≏ ≏ } <t1(0,2),r> [r2[b5 ≏ ≏ 🚂2 ]] <r2<t0(2,0),r>> !{r2{b1 ≏ ≏ }}")
        
        // Train 2 moves to b1 (entering in the previous direction!)
        try p.assert2("r1: {r2{b1 ≏ 🟨🚂2 ≡ }} <t0,r> [r1[b2 ≏ 🚂1 ≏ ]] {r1{b3 ≏ ≏ }} <t1,r> [b4 ≏ ≏] {r2{b1 ≏ 🟨🚂2 ≡ }}",
                      "r3: {b3 ≏ ≏ } <t1(0,2),r> [b5 ≏ ≏ ] <t0(2,0),r> !{r2{b1 ≡ 🟨🚂2 ≏ }}")
    }
    
    func testMoveRouteLoop() throws {
        let layout = LayoutCCreator().newLayout()
        
        try layout.prepare(routeID: "r1", trainID: "1")
        try layout.prepare(routeID: "r3", trainID: "2")
        
        let p = try setup(layout: layout, fromBlockId: "b1", route: layout.routes[0])
        
        try p.assert2("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] {r2{b3 🛑🚂2 ≏ ≏ }} <t1> [b4 ≏ ≏] {r1{b1 🛑🚂1 ≏ ≏ }}",
                      "r3: {r2{b3 🛑🚂2 ≏ ≏ }} <t1(0,2)> [b5 ≏ ≏ ] <t0(2,0)> !{r1{b1 ≏ ≏ 🛑🚂1 }}")
        
        try p.start(routeID: "r1", trainID: "1")
        
        try p.assert2("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] {r2{b3 🛑🚂2 ≏ ≏ }} <t1> [b4 ≏ ≏] {r1{b1 🚂1 ≏ ≏ }}",
                      "r3: {r2{b3 🛑🚂2 ≏ ≏ }} <t1(0,2)> [b5 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ 🚂1 }}")
        
        try p.start(routeID: "r3", trainID: "2")
        
        try p.assert2("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] {r2{b3 🚂2 ≏ ≏ }} <r2<t1,r>> [b4 ≏ ≏] {r1{b1 🚂1 ≏ ≏ }}",
                      "r3: {r2{b3 🚂2 ≏ ≏ }} <r2<t1(0,2),r>> [r2[b5 ≏ ≏ ]] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ 🚂1 }}")
        
        try p.assert2("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] {r2{b3 ≡ 🚂2 ≏ }} <r2<t1,r>> [b4 ≏ ≏] {r1{b1 🚂1 ≏ ≏ }}",
                      "r3: {r2{b3 ≡ 🚂2 ≏ }} <r2<t1(0,2),r>> [r2[b5 ≏ ≏ ]] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ 🚂1 }}")
        
        try p.assert2("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] {r2{b3 ≡ ≡ 🚂2 }} <r2<t1,r>> [b4 ≏ ≏] {r1{b1 🚂1 ≏ ≏ }}",
                      "r3: {r2{b3 ≡ ≡ 🚂2 }} <r2<t1(0,2),r>> [r2[b5 ≏ ≏ ]] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ 🚂1 }}")
        
        try p.assert2("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] {b3 ≏ ≏ } <t1,r> [b4 ≏ ≏] {r1{b1 🚂1 ≏ ≏ }}",
                      "r3: {b3 ≏ ≏ } <t1(0,2),r> [r2[b5 ≡ 🟨🚂2 ≏ ]] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ 🚂1 }}")
        
        // Train 2 stops because block b1 is still in use by train 1.
        try p.assert2("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] {b3 ≏ ≏ } <t1,r> [b4 ≏ ≏] {r1{b1 🚂1 ≏ ≏ }}",
                      "r3: {b3 ≏ ≏ } <t1(0,2),r> [r2[b5 ≡ ≡ 🛑🚂2 ]] <r1<t0(2,0)>> !{r1{b1  ≏ ≏ 🚂1 }}")
        
        try p.assert2("r1: {r1{b1 ≡ 🚂1 ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] {b3 ≏ ≏ } <t1,r> [b4 ≏ ≏] {r1{b1 ≡ 🚂1 ≏ }}",
                      "r3: {b3 ≏ ≏ } <t1(0,2),r> [r2[b5 ≏ ≏ 🛑🚂2 ]] <r1<t0(2,0)>> !{r1{b1 ≏ 🚂1 ≡ }}")
        
        try p.assert2("r1: {r1{b1 ≡ ≡ 🚂1 }} <r1<t0>> [r1[b2 ≏ ≏ ]] {b3 ≏ ≏ } <t1,r> [b4 ≏ ≏] {r1{b1 ≡ ≡ 🚂1 }}",
                      "r3: {b3 ≏ ≏ } <t1(0,2),r> [r2[b5 ≏ ≏ 🛑🚂2 ]] <r1<t0(2,0)>> !{r1{b1 🚂1 ≡ ≡ }}")
        
        // Train 2 starts again because block 1 is now free (train 1 has moved to block 2).
        try p.assert2("r1: {r2{b1 ≏ ≏ }} <r2<t0,r>> [r1[b2 ≡ 🚂1 ≏ ]] {r1{b3 ≏ ≏ }} <t1,r> [b4 ≏ ≏] {r2{b1 ≏ ≏ }}",
                      "r3: {r1{b3 ≏ ≏ }} <t1(0,2),r> [r2[b5 ≏ ≏ 🚂2 ]] <r2<t0(2,0),r>> !{r2{b1 ≏ ≏ }}")
        
        try p.assert2("r1: {r2{b1 ≏ ≏ }} <r2<t0,r>> [r1[b2 ≡ ≡ 🚂1 ]] {r1{b3 ≏ ≏ }} <t1,r> [b4 ≏ ≏] {r2{b1 ≏ ≏ }}",
                      "r3: {r1{b3 ≏ ≏ }} <t1(0,2),r> [r2[b5 ≏ ≏ 🚂2 ]] <r2<t0(2,0),r>> !{r2{b1 ≏ ≏ }}")
        
        try p.assert2("r1: {r2{b1 ≏ 🟨🚂2 ≡ }} <t0,r> [r1[b2 ≏ ≏ 🚂1 ]] {r1{b3 ≏ ≏ }} <t1,r> [b4 ≏ ≏] {r2{b1 ≏ 🟨🚂2 ≡ }}",
                      "r3: {r1{b3 ≏ ≏ }} <t1(0,2),r> [b5 ≏ ≏ ] <t0(2,0),r> !{r2{b1 ≡ 🟨🚂2 ≏ }}")
        
        // Train 1 brakes because it has reached a station and should stop
        // Train 2 stops because it has reached the end of the last block of its route (b1).
        try p.assert2("r1: {r2{b1 🛑🚂2 ≡ ≡ }} <t0,r> [b2 ≏ ≏ ] {r1{b3 ≡ 🟨🚂1 ≏ }} <t1,r> [b4 ≏ ≏] {r2{b1 🛑🚂2 ≡ ≡ }}",
                      "r3: {r1{b3 ≡ 🟨🚂1 ≏ }} <t1(0,2),r> [b5 ≏ ≏ ] <t0(2,0),r> !{r2{b1 ≡ ≡ 🛑🚂2  }}")
        
        // Train 1 has stopped because it is in a station (b3). It will restart shortly after.
        try p.assert2("r1: {r2{b1 🛑🚂2 ≏ ≏ }} <t0,r> [b2 ≏ ≏ ] {r1{b3 ≡ ≡ 🛑🚂1 }} <t1,r> [b4 ≏ ≏] {r2{b1 🛑🚂2 ≏ ≏ }}",
                      "r3: {r1{b3 ≡ ≡ 🛑🚂1 }} <t1(0,2),r> [b5 ≏ ≏ ] <t0(2,0),r> !{r2{b1 ≏ ≏ 🛑🚂2 }}")

        try p.assert2("r1: {r2{b1 🛑🚂2 ≏ ≏ }} <t0,r> [b2 ≏ ≏ ] {r1{b3 ≏ ≏ 🛑🚂1 }} <t1,r> [b4 ≏ ≏] {r2{b1 🛑🚂2 ≏ ≏ }}",
                      "r3: {r1{b3 ≏ ≏ 🛑🚂1 }} <t1(0,2),r> [b5 ≏ ≏ ] <t0(2,0),r> !{r2{b1 ≏ ≏ 🛑🚂2 }}")

        // Artificially set the restart time to 0 which will make train 1 restart again
        layout.trains[0].timeUntilAutomaticRestart = 0
        
        XCTAssertEqual(p.layoutController.run(), .processed) // Train 1 is re-started
        XCTAssertEqual(p.layoutController.run(), .none)

        try p.assert2("r1: {r2{b1 🛑🚂2 ≏ ≏ }} <t0,r> [b2 ≏ ≏ ] {r1{b3 ≏ ≏ 🚂1 }} <r1<t1>> [r1[b4 ≏ ≏]] {r2{b1 🛑🚂2 ≏ ≏ }}",
                      "r3: {r1{b3 ≏ ≏ 🚂1 }} <r1<t1(0,2)>> [b5 ≏ ≏ ] <t0(2,0),r> !{r2{b1 ≏ ≏ 🛑🚂2 }}")

        try p.assert2("r1: {r2{b1 🛑🚂2 ≏ ≏ }} <t0,r> [b2 ≏ ≏ ] {b3 ≏ ≏ } <t1> [r1[b4 ≡ 🟨🚂1 ≏]] {r2{b1 🛑🚂2 ≏ ≏ }}",
                      "r3: {b3 ≏ ≏ } <t1(0,2)> [b5 ≏ ≏ ] <t0(2,0),r> !{r2{b1 ≏ ≏ 🛑🚂2 }}")

        // Train 1 stops again because there is a train in the next block b1 (train 2)
        try p.assert2("r1: {r2{b1 🛑🚂2 ≏ ≏ }} <t0,r> [b2 ≏ ≏ ] {b3 ≏ ≏ } <t1> [r1[b4 ≡ ≡ 🛑🚂1 ]] {r2{b1 🛑🚂2 ≏ ≏ }}",
                      "r3: {b3 ≏ ≏ } <t1(0,2)> [b5 ≏ ≏ ] <t0(2,0),r> !{r2{b1 ≏ ≏ 🛑🚂2 }}")

        // Let's remove train 2 artificially to allow train 1 to stop at the station b1
        try layout.remove(trainID: Identifier<Train>(uuid: "2"))
        try p.assert2("r1: {r1{b1 ≏ ≏ }} <t0,r> [b2 ≏ ≏ ] {b3 ≏ ≏ } <t1> [r1[b4 ≡ ≡ 🚂1 ]] {r1{b1 ≏ ≏ }}",
                      "r3: {b3 ≏ ≏ } <t1(0,2)> [b5 ≏ ≏ ] <t0(2,0),r> !{r1{b1 ≏ ≏ }}")

        try p.assert2("r1: {r1{b1 ≡ 🟨🚂1 ≏ }} <t0,r> [b2 ≏ ≏ ] {b3 ≏ ≏ } <t1> [b4 ≏ ≏ ] {r1{b1 ≡ 🟨🚂1 ≏ }}",
                      "r3: {b3 ≏ ≏ } <t1(0,2)> [b5 ≏ ≏ ] <t0(2,0),r> !{r1{b1 ≏ 🟨🚂1 ≡ }}")

        // Train 1 finally stops at the station b1 which is its final block of the route
        try p.assert2("r1: {r1{b1 ≡ ≡ 🛑🚂1 }} <t0,r> [b2 ≏ ≏ ] {b3 ≏ ≏ } <t1> [b4 ≏ ≏ ] {r1{b1 ≡ ≡ 🛑🚂1 }}",
                      "r3: {b3 ≏ ≏ } <t1(0,2)> [b5 ≏ ≏ ] <t0(2,0),r> !{r1{b1  🛑🚂1 ≡ ≡ }}")
    }
 
    func testEntryBrakeStopFeedbacks() throws {
        let layout = LayoutECreator().newLayout()
                        
        let train = layout.trains[0]
        
        let b3 = layout.block(for: Identifier<Block>(uuid: "b3"))!
        b3.brakeFeedbackNext = Identifier<Feedback>(uuid: "fb3.1")
        b3.stopFeedbackNext = Identifier<Feedback>(uuid: "fb3.2")

        XCTAssertEqual(b3.entryFeedback(for: .next), Identifier<Feedback>(uuid: "fb3.1"))
        XCTAssertEqual(b3.brakeFeedback(for: .next), Identifier<Feedback>(uuid: "fb3.1"))
        XCTAssertEqual(b3.stopFeedback(for: .next), Identifier<Feedback>(uuid: "fb3.2"))

        let p = try setup(layout: layout, fromBlockId: "s1", route: layout.routes[0])

        layout.strictRouteFeedbackStrategy = false

        try p.start()

        try p.assert("0: {r0{s1 🚂0 ≏ }} <r0<t1,l>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ≏ ] <t5> <t6> {s1 🚂0 ≏ }")
        try p.assert("0: {s1 ≏ } <t1,l> <t2,s> [r0[b1 ≡ 🚂0 ]] <r0<t3>> [r0[b2 ≏ ]] <t4> [b3 ≏ ≏ ≏ ] <t5> <t6> {s1 ≏ }")
        try p.assert("0: {s1 ≏ } <t1,l> <t2,s> [b1 ≏ ] <t3> [r0[b2 ≡ 🚂0 ]] <r0<t4>> [r0[b3 ≏ ≏ ≏ ]] <t5> <t6> {s1 ≏ }")

        // Let's put another train in s1
        layout.reserve("s1", with: "1", direction: .next)

        try p.assert("0: {r1{s1 ≏ }} <t1,l> <t2,s> [b1 ≏ ] <t3> [r0[b2 ≏ 🚂0 ]] <r0<t4>> [r0[b3 ≏ ≏ ≏ ]] <t5> <t6> {r1{s1 ≏ }}")
        try p.assert("0: {r1{s1 ≏ }} <t1,l> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≡ 🟨🚂0 ≏ ≏ ]] <t5> <t6> {r1{s1 ≏ }}")
        XCTAssertEqual(train.state, .braking)
        
        try p.assert("0: {r1{s1 ≏ }} <t1,l> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≏ ≡ 🛑🚂0 ≏ ]] <t5> <t6> {r1{s1 ≏ }}")
        
        XCTAssertTrue(train.automaticScheduling)
        XCTAssertEqual(train.state, .stopped)
        
        // Free s1 so the train finishes its route
        layout.free("s1")
        
        try p.assert("0: {r0{s1 ≏ }} <t1,l> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≏ ≏ 🚂0 ≏ ]] <r0<t5>> <r0<t6,r>> {r0{s1 ≏ }}")
        try p.assert("0: {r0{s1 ≏ }} <t1,l> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≏ ≏ ≡ 🚂0 ]] <r0<t5>> <r0<t6,r>> {r0{s1 ≏ }}")
        try p.assert("0: {r0{s1 ≡ 🛑🚂0 }} <t1,l> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ≏ ] <t5> <t6,r> {r0{s1 ≡ 🛑🚂0 }}")
        
        XCTAssertTrue(train.manualScheduling)
        XCTAssertEqual(train.state, .stopped)

        // Now let's reverse the train direction and pick the reverse route
        // TODO finish the test
//        p = try setup(layout: layout, fromBlockId: "s1", direction: .previous, route: layout.routes[1])
//        try p.assert("0: !{r0{s1 🛑🚂0 ≏ }} <t6,r> <t5> ![b3 ≏ ≏ ≏ ] <t4> ![b2 ≏ ] <t3> ![b1 ≏ ] <t2,s> <t1,l> !{r0{s1 🛑🚂0 ≏}}")
    }
    
    func testRouteStationRestart() throws {
        let layout = LayoutECreator().newLayout()

        let p = try setup(layout: layout, fromBlockId: "s1", route: layout.routes[2])
        
        try p.assert("2: {r0{s1 🛑🚂0 ≏ }} <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ } <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ] <t5> <t6(0,2)> {r0{s1 🛑🚂0 ≏ }}")

        layout.strictRouteFeedbackStrategy = false

        try p.start()

        XCTAssertTrue(p.train.automaticScheduling)

        try p.assert("2: {r0{s1 🚂0 ≏ }} <r0<t1,l>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ } <r0<t1,l>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ] <t5> <t6(0,2)> {r0{s1 🚂0 ≏ }}")
        try p.assert("2: {s1 ≏ } <t1,l> <t2,s> [r0[b1 ≡ 🚂0]] <r0<t3>> [r0[b2 ≏ ]] <t4> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ } <t1,l> <t2,s> [r0[b1 ≡ 🚂0]] <r0<t3>> [r0[b2 ≏ ]] <t4> [b3 ≏ ≏ ] <t5> <t6(0,2)> {s1 ≏ }")
        try p.assert("2: {s1 ≏ } <t1,l> <t2,s> [b1 ≏] <t3> [r0[b2 ≡ 🚂0 ]] <r0<t4>> [r0[b3 ≏ ≏ ]] <t5> <t6> {s2 ≏ } <t1,l> <t2,s> [b1 ≏] <t3> [r0[b2 ≡ 🚂0 ]] <r0<t4>> [r0[b3 ≏ ≏ ]] <t5> <t6(0,2)> {s1 ≏ }")
        try p.assert("2: {s1 ≏ } <t1,l> <t2,s> [b1 ≏] <t3> [b2 ≏ ] <t4> [r0[b3 ≡ 🚂0 ≏ ]] <r0<t5>> <r0<t6>> {r0{s2 ≏ }} <t1,l> <t2,s> [b1 ≏] <t3> [b2 ≏ ] <t4> [r0[b3 ≡ 🚂0 ≏ ]] <r0<t5>> <r0<t6(0,2)>> {s1 ≏ }")
        try p.assert("2: {s1 ≏ } <t1,l> <t2,s> [b1 ≏] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ] <t5> <t6> {r0{s2 ≡ 🛑🚂0 }} <t1,l> <t2,s> [b1 ≏] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ] <t5> <t6(0,2)> {s1 ≏ }")
        
        XCTAssertTrue(p.train.automaticScheduling)

        // Artificially set the restart time to 0 which will make the train restart again
        layout.trains[0].timeUntilAutomaticRestart = 0

        XCTAssertEqual(p.layoutController.run(), .processed) // Train is re-started
        XCTAssertEqual(p.layoutController.run(), .none)

        XCTAssertTrue(p.train.speed.kph > 0)
        
        // Assert that the train has restarted and is moving in the correct direction
        try p.assert("2: {s1 ≏ } <r0<t1,s>> <r0<t2,s>> [r0[b1 ≏]] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ] <t5> <t6> {r0{s2 ≏ 🚂0 }} <r0<t1,s>> <r0<t2,s>> [r0[b1 ≏]] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ] <t5> <t6(0,2)> {s1 ≏ }")
        try p.assert("2: {s1 ≏ } <t1,s> <t2,s> [r0[b1 ≡ 🚂0]] <r0<t3>> [r0[b2 ≏ ]] <t4> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ } <t1,s> <t2,s> [r0[b1 ≡ 🚂0]] <r0<t3>> [r0[b2 ≏ ]] <t4> [b3 ≏ ≏ ] <t5> <t6(0,2)> {s1 ≏ }")
        try p.assert("2: {s1 ≏ } <t1,s> <t2,s> [b1 ≏ ] <t3> [r0[b2 ≡ 🚂0 ]] <r0<t4>> [r0[b3 ≏ ≏ ]] <t5> <t6> {s2 ≏ } <t1,s> <t2,s> [b1 ≏ ] <t3> [r0[b2 ≡ 🚂0 ]] <r0<t4>> [r0[b3 ≏ ≏ ]] <t5> <t6(0,2)> {s1 ≏ }")
        try p.assert("2: {r0{s1 ≏ }} <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≡ 🚂0 ≏ ]] <r0<t5>> <r0<t6,r>> {s2 ≏ } <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≡ 🚂0 ≏ ]] <r0<t5>> <r0<t6(0,2),r>> {r0{s1 ≏ }}")
        try p.assert("2: {r0{s1 ≡ 🛑🚂0 }} <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ]] <t5> <t6,r> {s2 ≏ } <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ] <t5> <t6(0,2),r> {r0{s1 ≡ 🛑🚂0 }}")
        
        XCTAssertTrue(p.train.manualScheduling)
    }

    func testUpdateAutomaticRouteBrakingAndContinue() throws {
        let layout = LayoutHCreator().newLayout()

        let p = try setup(layout: layout, fromBlockId: "A", position: .end, route: layout.routes[0])
        try p.start()
        
        try p.assert("0: |[r0[A ≏ ≏ 🚂0 ]] <r0<AB>> [r0[B ≏ ≏ ]] [C ≏ ≏ ] [D ≏ ≏ ] <DE> [E ≏ ≏ ]|")
        try p.assert("0: |[r0[A ≏ ≏ 💺0 ]] <r0<AB>> [r0[B 💺0 ≡ 🚂0 ≏ ]] [r0[C ≏ ≏ ]] [D ≏ ≏ ] <DE> [E ≏ ≏ ]|")
        try p.assert("0: |[r0[A ≏ ≏ 💺0 ]] <r0<AB>> [r0[B 💺0 ≏ 💺0 ≡ 🚂0 ]] [r0[C ≏ ≏ ]] [D ≏ ≏ ] <DE> [E ≏ ≏ ]|")

        // Let's put another train in D
        layout.reserve("D", with: "1", direction: .next)

        // The train should brake
        try p.assert("0: |[A ≏ ≏ ] <AB> [r0[B 💺0 ≏ 💺0 ≏ 💺0 ]] [r0[C 💺0 ≡ 🟨🚂0 ≏ ]] [r1[D ≏ ≏ ]] <DE> [E ≏ ≏ ]|")
        
        // And now we free D...
        layout.free("D")

        // Which means the train should start accelerating again
        try p.assert("0: |[A ≏ ≏ ] <AB> [r0[B 💺0 ≏ 💺0 ≏ 💺0 ]] [r0[C 💺0 ≏ 💺0 ≡ 🚂0 ]] [r0[D ≏ ≏ ]] <DE> [E ≏ ≏ ]|")
        try p.assert("0: |[A ≏ ≏ ] <AB> [B ≏ ≏ ] [r0[C 💺0 ≏ 💺0 ≏ 💺0 ]] [r0[D 💺0 ≡ 🚂0 ≏ ]] <r0<DE>> [r0[E ≏ ≏ ]]|")
        try p.assert("0: |[A ≏ ≏ ] <AB> [B ≏ ≏ ] [r0[C 💺0 ≏ 💺0 ≏ 💺0 ]] [r0[D 💺0 ≏ 💺0 ≡ 🚂0 ]] <r0<DE>> [r0[E ≏ ≏ ]]|")
        try p.assert("0: |[A ≏ ≏ ] <AB> [B ≏ ≏ ] [C ≏ ≏ ] [r0[D 💺0 ≏ 💺0 ≏ 💺0 ]] <r0<DE>> [r0[E 💺0 ≡ 🟨🚂0 ≏ ]]|")
        
        p.toggle("E.2")

        XCTAssertEqual(p.train.state, .stopped)
    }

    func testTrainWithWagonsInFront() throws {
        let layout = LayoutECreator().newLayoutWithLengths()
        layout.turnouts[0].state = .branchLeft
        layout.turnouts[5].state = .branchRight

        let train = layout.trains[0]
        train.wagonsPushedByLocomotive = true

        let p = try setup(layout: layout, fromBlockId: "s1", position: .start, route: layout.routes[3])

        try p.assert("3: {r0{s1 🛑🚂0 ≏ 💺0 }} <r0<t1,l>> <r0<t2,s>> [r0[b1 💺0 ≏ 💺0 ]] <r0<t3>> [r0[b2 💺0 ≏ ]] <t4> [b3 ≏ ≏ ] <t5> <t6,r> {s2 ≏ }")
        
        layout.strictRouteFeedbackStrategy = false

        try p.start()

        XCTAssertTrue(p.train.automaticScheduling)
        
        // block length = 60
        // train length = 100
        try p.assert("3: {r0{s1 🚂0 ≏ 💺0 }} <r0<t1,l>> <r0<t2,s>> [r0[b1 💺0 ≏ 💺0 ]] <r0<t3>> [r0[b2 💺0 ≏ ]] <r0<t4>> [r0[b3 ≏ ≏ ]] <t5> <t6,r> {s2 ≏ }")
        try p.assert("3: {r0{s1 ≡ 🚂0 }} <r0<t1,l>> <r0<t2,s>> [r0[b1 💺0 ≏ 💺0 ]] <r0<t3>> [r0[b2 💺0 ≏ 💺0 ]] <r0<t4>> [r0[b3 ≏ ≏ ]] <t5> <t6,r> {s2 ≏ }")
    }
    
    func testStraightLine1() throws {
        let layout = LayoutHCreator().newLayout()

        let p = try setup(layout: layout, fromBlockId: "A", position: .end, route: layout.routes[0])

        try p.assert("0: |[r0[A 💺0 ≏ 💺0 ≏ 🛑🚂0 ]] <AB> [B ≏ ≏ ] [C ≏ ≏ ] [D ≏ ≏ ] <DE> [E ≏ ≏ ]|")
        
        try p.start()

        XCTAssertTrue(p.train.automaticScheduling)

        // A = 200
        // B=C=D=100
        // AB=DE=10
        // Train = 120
        // [A 20 ≏ 160 ≏ 20 ] <10> [B 20 ≏ 60 ≏ 20 ] [C 20 ≏ 60 ≏ 20 ] [D 20 ≏ 60 ≏ 20 ] <10> [E 20 ≏ 160 ≏ 20 ]
        try p.assert("0: |[r0[A 💺0 ≏ 💺0 ≏ 🚂0 ]] <r0<AB>> [r0[B ≏ ≏ ]] [C ≏ ≏ ] [D ≏ ≏ ] <DE> [E ≏ ≏ ]|")
        try p.assert("0: |[r0[A ≏ 💺0 ≏ 💺0 ]] <r0<AB>> [r0[B 💺0 ≡ 🚂0 ≏ ]] [r0[C ≏ ≏ ]] [D ≏ ≏ ] <DE> [E ≏ ≏ ]|")
        try p.assert("0: |[r0[A ≏ 💺0 ≏ 💺0 ]] <r0<AB>> [r0[B 💺0 ≏ 💺0 ≡ 🚂0 ]] [r0[C ≏ ≏ ]] [D ≏ ≏ ] <DE> [E ≏ ≏ ]|")
        try p.assert("0: |[A ≏ ≏ ] <AB> [r0[B 💺0 ≏ 💺0 ≏ 💺0 ]] [r0[C 💺0 ≡ 🚂0 ≏ ]] [r0[D ≏ ≏ ]] <DE> [E ≏ ≏ ]|")
        try p.assert("0: |[A ≏ ≏ ] <AB> [r0[B ≏ 💺0 ≏ 💺0 ]] [r0[C 💺0 ≏ 💺0 ≡ 🚂0 ]] [r0[D ≏ ≏ ]] <DE> [E ≏ ≏ ]|")
        try p.assert("0: |[A ≏ ≏ ] <AB> [B ≏ ≏ ] [r0[C 💺0 ≏ 💺0 ≏ 💺0]] [r0[D 💺0 ≡ 🚂0 ≏ ]] <r0<DE>> [r0[E ≏ ≏ ]]|")
        try p.assert("0: |[A ≏ ≏ ] <AB> [B ≏ ≏ ] [r0[C 💺0 ≏ 💺0 ≏ 💺0]] [r0[D 💺0 ≏ 💺0 ≡ 🚂0 ]] <r0<DE>> [r0[E ≏ ≏ ]]|")
        try p.assert("0: |[A ≏ ≏ ] <AB> [B ≏ ≏ ] [C ≏ ≏ ] [r0[D 💺0 ≏ 💺0 ≏ 💺0 ]] <r0<DE>> [r0[E 💺0 ≡ 🟨🚂0 ≏ ]]|")
        try p.assert("0: |[A ≏ ≏ ] <AB> [B ≏ ≏ ] [C ≏ ≏ ] [D ≏ ≏ ] <DE> [r0[E ≏ 💺0 ≡ 🛑🚂0 ]]|")
    }

    func testStraightLine1Pushed() throws {
        let layout = LayoutHCreator().newLayout()
        layout.trains[0].wagonsPushedByLocomotive = true
        
        let p = try setup(layout: layout, fromBlockId: "A", position: .start, route: layout.routes[0])

        try p.assert("0: |[r0[A 🛑🚂0 ≏ 💺0 ≏ 💺0 ]] <AB> [B ≏ ≏ ] [C ≏ ≏ ] [D ≏ ≏ ] <DE> [E ≏ ≏ ]|")
        
        try p.start()

        XCTAssertTrue(p.train.automaticScheduling)

        // A = 200
        // B=C=D=100
        // AB=DE=10
        // Train = 120
        // [A 20 ≏ 160 ≏ 20 ] <10> [B 20 ≏ 60 ≏ 20 ] [C 20 ≏ 60 ≏ 20 ] [D 20 ≏ 60 ≏ 20 ] <10> [E 20 ≏ 160 ≏ 20 ]
        try p.assert("0: |[r0[A 🚂0 ≏ 💺0 ≏ 💺0]] <r0<AB>> [r0[B ≏ ≏ ]] [C ≏ ≏ ] [D ≏ ≏ ] <DE> [E ≏ ≏ ]|")
        try p.assert("0: |[r0[A ≡ 🚂0 ≏ 💺0 ]] <r0<AB>> [r0[B 💺0 ≏ 💺0 ≏ ]] [r0[C ≏ ≏ ]] [D ≏ ≏ ] <DE> [E ≏ ≏ ]|")
        // TODO: have a unit test to ensure the train stops when pushing wagons when a block ahead cannot be reserved
        try p.assert("0: |[r0[A ≏ ≡ 🚂0 ]] <r0<AB>> [r0[B 💺0 ≏ 💺0 ≏ 💺0 ]] [r0[C 💺0 ≏ ≏ ]] [r0[D ≏ ≏ ]] <DE> [E ≏ ≏ ]|")
        try p.assert("0: |[A ≏ ≏ ] <AB> [r0[B ≡ 🚂0 ≏ 💺0 ]] [r0[C 💺0 ≏ 💺0 ≏ 💺0 ]] [r0[D ≏ ≏ ]] <DE> [E ≏ ≏ ]|")
        try p.assert("0: |[A ≏ ≏ ] <AB> [r0[B ≏ ≡ 🚂0 ]] [r0[C 💺0 ≏ 💺0 ≏ 💺0 ]] [r0[D 💺0 ≏ ≏ ]] <r0<DE>> [r0[E ≏ ≏ ]]|")
        try p.assert("0: |[A ≏ ≏ ] <AB> [B ≏ ≏ ] [r0[C ≡ 🚂0 ≏ 💺0]] [r0[D 💺0 ≏ 💺0 ≏ 💺0 ]] <r0<DE>> [r0[E ≏ ≏ ]]|")
        try p.assert("0: |[A ≏ ≏ ] <AB> [B ≏ ≏ ] [r0[C ≏ ≡ 🚂0 ]] [r0[D 💺0 ≏ 💺0 ≏ 💺0 ]] <r0<DE>> [r0[E 💺0 ≏ ≏ ]]|")
        try p.assert("0: |[A ≏ ≏ ] <AB> [B ≏ ≏ ] [C ≏ ≏ ] [r0[D ≡ 🟨🚂0 ≏ 💺0 ]] <r0<DE>> [r0[E 💺0 ≏ 💺0 ≏ ]]|")
        // TODO: tweak the algorithm to allow the entire train to stop in the E block if there is enough space
        try p.assert("0: |[A ≏ ≏ ] <AB> [B ≏ ≏ ] [C ≏ ≏ ] [r0[D ≏ ≡ 🛑🚂0 ]] <r0<DE>> [r0[E 💺0 ≏ 💺0 ≏ ]]|")
//        try p.assert("0: |[A ≏ ≏ ] <AB> [B ≏ ≏ ] [C ≏ ≏ ] [D ≏ ≏ ] <DE> [r0[E ≏ 💺0 ≡ 🛑🚂0 ]]|")
    }

    func testStraightLine2() throws {
        let layout = LayoutHCreator().newLayout()

        let p = try setup(layout: layout, fromBlockId: "A", position: .end, route: layout.routes[1])

        try p.assert("1: |[r0[A 💺0 ≏ 💺0 ≏ 🛑🚂0 ]] <AB> [B2 ≏ ≏ ] ![C2 ≏ ≏ ] [D2 ≏ ≏ ] <DE> [E ≏ ≏ ]|")
        
        try p.start()

        XCTAssertTrue(p.train.automaticScheduling)

        // A = 200
        // B=C=D=100
        // AB=DE=10
        // Train = 120
        // [A 20 ≏ 160 ≏ 20 ] <10> [B2 20 ≏ 60 ≏ 20 ] [C2 20 ≏ 60 ≏ 20 ] [D2 20 ≏ 60 ≏ 20 ] <10> [E 20 ≏ 160 ≏ 20 ]
        try p.assert("1: |[r0[A 💺0 ≏ 💺0 ≏ 🚂0 ]] <r0<AB,r>> [r0[B2 ≏ ≏ ]] ![C2 ≏ ≏ ] [D2 ≏ ≏ ] <DE> [E ≏ ≏ ]|")
        try p.assert("1: |[r0[A ≏ 💺0 ≏ 💺0 ]] <r0<AB,r>> [r0[B2 💺0 ≡ 🚂0 ≏ ]] ![r0[C2 ≏ ≏ ]] [D2 ≏ ≏ ] <DE> [E ≏ ≏ ]|")
        try p.assert("1: |[r0[A ≏ 💺0 ≏ 💺0 ]] <r0<AB,r>> [r0[B2 💺0 ≏ 💺0 ≡ 🚂0 ]] ![r0[C2 ≏ ≏ ]] [D2 ≏ ≏ ] <DE> [E ≏ ≏ ]|")
        try p.assert("1: |[A ≏ ≏ ] <AB,r> [r0[B2 💺0 ≏ 💺0 ≏ 💺0 ]] ![r0[C2 💺0 ≡ 🚂0 ≏ ]] [r0[D2 ≏ ≏ ]] <DE> [E ≏ ≏ ]|")
        try p.assert("1: |[A ≏ ≏ ] <AB,r> [r0[B2 ≏ 💺0 ≏ 💺0 ]] ![r0[C2 💺0 ≏ 💺0 ≡ 🚂0]] [r0[D2 ≏ ≏ ]] <DE> [E ≏ ≏ ]|")
        try p.assert("1: |[A ≏ ≏ ] <AB,r> [B2 ≏ ≏ ] ![r0[C2 💺0 ≏ 💺0 ≏ 💺0]] [r0[D2 💺0 ≡ 🚂0 ≏ ]] <r0<DE,l>> [r0[E ≏ ≏ ]]|")
        try p.assert("1: |[A ≏ ≏ ] <AB,r> [B2 ≏ ≏ ] ![r0[C2 💺0 ≏ 💺0 ≏ 💺0]] [r0[D2 💺0 ≏ 💺0 ≡ 🚂0 ]] <r0<DE,l>> [r0[E ≏ ≏ ]]|")
        try p.assert("1: |[A ≏ ≏ ] <AB,r> [B2 ≏ ≏ ] ![C2 ≏ ≏ ] [r0[D2 💺0 ≏ 💺0 ≏ 💺0 ]] <r0<DE,l>> [r0[E 💺0 ≡ 🟨🚂0 ≏ ]]|")
        try p.assert("1: |[A ≏ ≏ ] <AB,r> [B2 ≏ ≏ ] ![C2 ≏ ≏ ] [D2 ≏ ≏ ] <DE,l> [r0[E ≏ 💺0 ≡ 🛑🚂0 ]]|")
    }

    func testASCIIProducer() throws {
        let layout = LayoutACreator().newLayout()
        let producer = LayoutASCIIProducer(layout: layout)
        let route = layout.routes[0]
        
        let p = try setup(layout: layout, fromBlockId: "b1", position: .start, route: route)

        XCTAssertEqual(try producer.stringFrom(route: route), "{r1{b1 🛑🚂1 ≏ ≏ }} <t0{sl}(0,1),s> [b2 ≏ ≏ ] <t1{sl}(0,1),s> [b3 ≏ ≏ ] <t1{sl},s> !{r1{b1 🛑🚂1 ≏ ≏ }}")
        
        try p.start()
        XCTAssertEqual(try producer.stringFrom(route: route), "{r1{b1 🚂1 ≏ ≏ }} <r1<t0{sl}(0,1),s>> [r1[b2 ≏ ≏ ]] <t1{sl}(0,1),s> [b3 ≏ ≏ ] <t1{sl},s> !{r1{b1 🚂1 ≏ ≏ }}")
        
        p.toggle("f11")
        XCTAssertEqual(try producer.stringFrom(route: route), "{r1{b1 ≡ 🚂1 ≏ }} <r1<t0{sl}(0,1),s>> [r1[b2 ≏ ≏ ]] <t1{sl}(0,1),s> [b3 ≏ ≏ ] <t1{sl},s> !{r1{b1 ≡ 🚂1 ≏ }}")
        
        p.toggle2("f11", "f12")
        XCTAssertEqual(try producer.stringFrom(route: route), "{r1{b1 ≏ ≡ 🚂1 }} <r1<t0{sl}(0,1),s>> [r1[b2 ≏ ≏ ]] <t1{sl}(0,1),s> [b3 ≏ ≏ ] <t1{sl},s> !{r1{b1 ≏ ≡ 🚂1 }}")
        
        p.toggle2("f12", "f21")
        XCTAssertEqual(try producer.stringFrom(route: route), "{b1 ≏ ≏ } <t0{sl}(0,1),s> [r1[b2 ≡ 🚂1 ≏ ]] <r1<t1{sl}(0,2),l>> [r1[b3 ≏ ≏ ]] <r1<t1{sl}(2,0),l>> !{b1 ≏ ≏ }")
        
        p.toggle2("f21", "f22")
        XCTAssertEqual(try producer.stringFrom(route: route), "{b1 ≏ ≏ } <t0{sl}(0,1),s> [r1[b2 ≏ ≡ 🚂1 ]] <r1<t1{sl}(0,2),l>> [r1[b3 ≏ ≏ ]] <r1<t1{sl}(2,0),l>> !{b1 ≏ ≏ }")
        
        p.toggle2("f22", "f31")
        XCTAssertEqual(try producer.stringFrom(route: route), "{r1{b1 ≏ ≏ }} <r1<t0{sl}(0,2),l>> [b2 ≏ ≏ ] <t1{sl}(0,2),l> [r1[b3 ≡ 🚂1 ≏ ]] <t1{sl}(2,0),l> !{r1{b1 ≏ ≏ }}")
        
        p.toggle2("f31", "f32")
        XCTAssertEqual(try producer.stringFrom(route: route), "{r1{b1 ≏ ≏ }} <r1<t0{sl}(0,2),l>> [b2 ≏ ≏ ] <t1{sl}(0,2),l> [r1[b3 ≏ ≡ 🚂1 ]] <t1{sl}(2,0),l> !{r1{b1 ≏ ≏ }}")
        
        p.toggle2("f32", "f12")
        XCTAssertEqual(try producer.stringFrom(route: route), "{r1{b1 ≏ 🟨🚂1 ≡ }} <t0{sl}(0,2),l> [b2 ≏ ≏ ] <t1{sl}(0,2),l> [b3 ≏ ≏ ] <t1{sl}(2,0),l> !{r1{b1 ≏ 🟨🚂1 ≡ }}")
        
        p.toggle2("f12", "f11")
        XCTAssertEqual(try producer.stringFrom(route: route), "{r1{b1 🛑🚂1 ≡ ≏ }} <t0{sl}(0,2),l> [b2 ≏ ≏ ] <t1{sl}(0,2),l> [b3 ≏ ≏ ] <t1{sl}(2,0),l> !{r1{b1 🛑🚂1 ≡ ≏ }}")
    }

    // MARK: -- Utility
    
    // Convenience structure to test the layout and its route
    private struct Package {
        let layout: Layout
        let train: Train
        let route: Route
        let asserter: LayoutAsserter
        let layoutController: LayoutController
        
        func start() throws {
            try layoutController.start(routeID: route.id, trainID: train.id, destination: nil)
            XCTAssertTrue(train.automaticScheduling)
            XCTAssertEqual(train.state, .running)
        }

        func start(routeID: String, trainID: String) throws {
            try layoutController.start(routeID: Identifier<Route>(uuid: routeID), trainID: Identifier<Train>(uuid: trainID), destination: nil)
            let train = layout.train(for: Identifier<Train>(uuid: trainID))!
            XCTAssertTrue(train.automaticScheduling)
            XCTAssertEqual(train.state, .running)
        }
        
        func toggle(_ feedback: String) {
            layout.feedback(for: Identifier<Feedback>(uuid: feedback))?.detected.toggle()
            _ = layoutController.run()
        }

        func toggle2(_ f1: String, _ f2: String) {
            toggle(f1)
            toggle(f2)
            _ = layoutController.run()
        }

        func assert(_ r1: String) throws {
            try asserter.assert([r1], route:route, trains: [train])
        }
        
        func assert2(_ r1: String, _ r2: String) throws {
            try asserter.assert([r1, r2], route:route, trains: [train])
        }
    }
    
    private func setup(layout: Layout, fromBlockId: String, position: Position = .start, direction: Direction = .next, route: Route) throws -> Package {
        layout.detectUnexpectedFeedback = true
        layout.strictRouteFeedbackStrategy = true

        let train = layout.trains[0]
        try layout.setTrainToBlock(train.id, Identifier<Block>(uuid: fromBlockId), position: position, direction: direction)
        
        XCTAssertEqual(train.speed.kph, 0)
        XCTAssertTrue(train.manualScheduling)
        XCTAssertEqual(train.state, .stopped)

        let layoutController = LayoutController(layout: layout, switchboard: nil, interface: nil)
        let asserter = LayoutAsserter(layout: layout, layoutController: layoutController)
        return Package(layout: layout, train: train, route: route, asserter: asserter, layoutController: layoutController)
    }

}
