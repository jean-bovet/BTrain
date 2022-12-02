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

/// Tests that take into account the fact that a turnout state actually changes with a delay in a physical layout. The train controller
/// needs to handle that delay appropriately, by braking or stopping the train until the turnouts are fully settled.
class FixedRoutingWithTurnoutDelays: BTTestCase {
    func testMoveInsideBlockWithTurnoutDelay() throws {
        let layout = LayoutLoop1().newLayout().removeTrainGeometry()
        let t0 = layout.turnout(named: "t0")
        t0.setState(.branchLeft)

        let p = Package(layout: layout)
        p.digitalController.pause()

        try p.prepare(routeID: "r1", trainID: "1", fromBlockId: "b1")

        // t0 has still the state .branchLeft instead of the requested .straight
        try p.assert("r1: {r1{b1 🔴􀼮1 ≏ ≏ }} <t0,l> [b2 ≏ ≏ ] <t1(0,2)> [b3 ≏ ≏ ] <t0(2,0),l> !{r1{b1 ≏ ≏ }}")

        // The train will switch to managed scheduling but does not start yet because the turnout t0 hasn't settled.
        try p.start(expectedState: .running)

        // t0 has still the state .branchLeft instead of the requested .straight
        try p.assert("r1: {r1{b1 🔵􀼮1 ≏ ≏ }} <r1<t0,l>> [r1[b2 ≏ ≏ ]] <t1(0,2)> [b3 ≏ ≏ ] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≡ 🔵􀼮1 ≏ }} <r1<t0,l>> [r1[b2 ≏ ≏ ]] <t1(0,2)> [b3 ≏ ≏ ] <r1<t0(2,0),l>> !{r1{b1 ≏ ≡ }}")

        // The train stops because t0 has not yet settled, hence the leading distance is 0.
        try p.assert("r1: {r1{b1 ≏ ≡ 🔴􀼮1 }} <r1<t0,l>> [r1[b2 ≏ ≏ ]] <t1(0,2)> [b3 ≏ ≏ ] <r1<t0(2,0),l>> !{r1{b1 ≡ ≏ }}")

        // This will settle the turnout t0
        p.digitalController.resume()
        p.layoutController.runControllers(.turnoutChanged(t0))
        p.layoutController.waitUntilSettled()

        // And the train will restart because the leading turnouts are settled
        XCTAssertEqual(p.train.state, .running)

        try p.assert("r1: {r1{b1 ≏ ≡ 🔵􀼮1 }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1(0,2)> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≡ ≏ }}")

        // Pause again the turnout executor which will prevent the leading turnouts from settling
        p.digitalController.pause()

        // The train will stop because the leading turnouts are not yet fully settled
        try p.assert("r1: {b1 ≏ ≏ } <t0> [r1[b2 ≡ 🟡􀼮1 ≏ ]] <r1<t1(0,2),s>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        try p.assert("r1: {b1 ≏ ≏ } <t0> [r1[b2 ≏ ≡ 🔴􀼮1 ]] <r1<t1(0,2),s>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")

        // Resuming the executor which will settle the leading turnouts
        p.digitalController.resume()

        // The train restarts because all the turnouts have settled
        try p.assert("r1: {b1 ≏ ≏ } <t0> [r1[b2 ≏ ≏ 🔵􀼮1 ]] <r1<t1(0,2),l>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [b2 ≏ ≏ ] <t1(0,2),l> [r1[b3 ≡ 🔵􀼮1 ≏ ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [b2 ≏ ≏ ] <t1(0,2),l> [r1[b3 ≏ 🔵􀼮1 ≏ ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [b2 ≏ ≏ ] <t1(0,2),l> [r1[b3 ≏ ≡ 🔵􀼮1 ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ 🟡!􀼮1 ≡ }} <t0,l> [b2 ≏ ≏ ] <t1(0,2),l> [b3 ≏ ≏ ] <t0(2,0),l> !{r1{b1 ≡ 🟡􀼮1 ≏ }}")
        try p.assert("r1: {r1{b1 ≏ 🟡!􀼮1 ≏ }} <t0,l> [b2 ≏ ≏ ] <t1(0,2),l> [b3 ≏ ≏ ] <t0(2,0),l> !{r1{b1 ≏ 🟡􀼮1 ≏ }}")
        try p.assert("r1: {r1{b1 🔴!􀼮1 ≡ ≏ }} <t0,l> [b2 ≏ ≏ ] <t1(0,2),l> [b3 ≏ ≏ ] <t0(2,0),l> !{r1{b1 ≏ ≡ 🔴􀼮1 }}")
    }

    func testLeadingSettledDistance() throws {
        let layout = LayoutLoop2().newLayout()
        layout.block(named: "b3").category = .free

        let t1 = layout.turnout(named: "t1")
        t1.setState(.branchRight)

        let p = Package(layout: layout)
        try p.prepare(routeID: "r1", trainID: "1", fromBlockId: "b1", position: .end)

        p.train.maxNumberOfLeadingReservedBlocks = 2

        try p.assert("r1: {r1{b1 ≏ 􀼯1 ≏ 🔴􀼮1 }} <t0> [b2 ≏ ≏ ] [b3 ≏ ≏ ] <t1,r> [b4 ≏ ≏] {r1{b1 ≏ ≏ }}")

        try p.start()

        try p.assert("r1: {r1{b1 ≏ 􀼯1 ≏ 🟢􀼮1 }} <r1<t0>> [r1[b2 ≏ ≏ ]] [r1[b3 ≏ ≏ ]] <t1,r> [b4 ≏ ≏] {r1{b1 ≏ ≏ }}")
        XCTAssertEqual(p.train.state, .running)

        p.digitalController.pause()

        // Train is now braking because not enough leading settled distance
        try p.assert("r1: {b1 ≏ ≏ } <t0> [r1[b2 􀼯1 ≡ 🔵􀼮1 ≏ ]] [r1[b3 ≏ ≏ ]] <r1<t1,r>> [r1[b4 ≏ ≏]] {b1 ≏ ≏ }")
        XCTAssertEqual(p.train.state, .running)

        try p.assert("r1: {r1{b1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] [r1[b3 􀼯1 ≡ 🟡􀼮1 ≏ ]] <r1<t1,r>> [r1[b4 ≏ ≏]] {r1{b1 ≏ ≏ }}")
        XCTAssertEqual(p.train.state, .running)

        p.digitalController.resume()
        p.layoutController.waitUntilSettled()

        // And the train will restart because the leading turnouts are settled
        XCTAssertEqual(p.train.state, .running)

        try p.assert("r1: {r1{b1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] [r1[b3 􀼯1 ≡ 🟢􀼮1 ≏ ]] <r1<t1>> [r1[b4 ≏ ≏]] {r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] [r1[b3 ≏ 􀼯1 ≡ 🟢􀼮1 ]] <r1<t1>> [r1[b4 ≏ ≏]] {r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] [b3 ≏ ≏ ] <t1> [r1[b4 􀼯1 ≡ 🔵􀼮1 ≏]] {r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] [b3 ≏ ≏ ] <t1> [r1[b4 ≏ 􀼯1 ≡ 🔵􀼮1]] {r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 􀼯1 ≡ 🟡􀼮1 ≏ }} <t0> [b2 ≏ ≏ ] [b3 ≏ ≏ ] <t1> [b4 ≏ ≏ ] {r1{b1 􀼯1 ≡ 🟡􀼮1 ≏ }}")
        try p.assert("r1: {r1{b1 ≏ 􀼯1 ≡ 🔴􀼮1 }} <t0> [b2 ≏ ≏ ] [b3 ≏ ≏ ] <t1> [b4 ≏ ≏ ] {r1{b1 ≏ 􀼯1 ≡ 🔴􀼮1 }}")
    }
}
