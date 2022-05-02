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

class AutomaticRoutingTests: BTTestCase {

    func testUpdateAutomaticRoute() throws {
        let layout = LayoutComplexLoop().newLayout()
        let s1 = layout.block(for: Identifier<Block>(uuid: "s1"))!

        let p = try setup(layout: layout, fromBlockId: s1.id, destination: nil, position: .end, routeSteps: ["s1:next", "b1:next", "b2:next", "b3:next", "s2:next"])
        
        try p.assert("automatic-0: {r0{s1 ≏ 🔵🚂0 }} <r0<t1(2,0),l>> <r0<t2(1,0),s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4(1,0)> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }", ["b1"])
                                
        // Let's put another train in b2
        layout.reserve("b2", with: "1", direction: .next)
        
        try p.assert("automatic-0: {r0{s1 ≏ 🔵🚂0 }} <r0<t1(2,0),l>> <r0<t2(1,0),s>> [r0[b1 ≏ ]] <t3> [r1[b2 ≏ ]] <t4(1,0)> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }", ["b1"])

        // Move s1 -> b1
        // The controller will generate a new automatic route because "b2" is occupied.
        try p.assert("automatic-0: [r0[b1 💺0 ≡ 🟡🚂0 ]] <r0<t3(0,2),r>> ![r0[b5 ≏ ]] <t7{sr}(2,0),s> <t5{sr}(2,0),s> ![b3 ≏ ≏ ≏ ] <t4{sl}(0,1),s> ![r1[b2 ≏ ]] <r0<t3(1,0),r>> ![r0[b1 🟡🚂0 ≡ 💺0 ]] <t2{sl}(0,1),s> <t1{sl}(0,1),l> !{s2 ≏ }", ["b5"])
        
        // Move b1 -> b5
        try p.assert("automatic-0: [b1 ≏ ] <t3(0,2),r> ![r0[b5 ≡ 🔵🚂0 ]] <r0<t7(2,0),r>> <r0<t5(2,0),r>> ![r0[b3 ≏ ≏ ]] <t4(0,1)> ![r1[b2 ≏ ]] <t3(1,0),r> ![b1 ≏ ] <t2(0,1)> <t1(0,1),l> !{s2 ≏ }", ["b3"])

        // Let's remove the occupation of b2
        layout.free("b2")
        try p.assert("automatic-0: [b1 ≏ ] <t3(0,2),r> ![r0[b5 ≡ 🔵🚂0 ]] <r0<t7(2,0),r>> <r0<t5(2,0),r>> ![r0[b3 ≏ ≏ ]] <t4(0,1)> ![b2 ≏ ] <t3(1,0),r> ![b1 ≏ ] <t2(0,1)> <t1(0,1),l> !{s2 ≏ }", ["b3"])

        // Move b5 -> b3
        try p.assert("automatic-0: [b1 ≏ ] <t3(0,2),r> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![r0[b3 ≡ 🔵🚂0 ≏ ≏ ]] <r0<t4(0,1)>> ![r0[b2 ≏ ]] <t3(1,0),r> ![b1 ≏ ] <t2(0,1)> <t1(0,1),l> !{s2 ≏ }", ["b2"])
        try p.assert("automatic-0: [b1 ≏ ] <t3(0,2),r> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![r0[b3 ≏ ≡ 🔵🚂0 ≏ ]] <r0<t4(0,1)>> ![r0[b2 ≏ ]] <t3(1,0),r> ![b1 ≏ ] <t2(0,1)> <t1(0,1),l> !{s2 ≏ }", ["b2"])
        try p.assert("automatic-0: [b1 ≏ ] <t3(0,2),r> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![r0[b3 ≏ ≏ ≡ 🔵🚂0 ]] <r0<t4(0,1)>> ![r0[b2 ≏ ]] <t3(1,0),r> ![b1 ≏ ] <t2(0,1)> <t1(0,1),l> !{s2 ≏ }", ["b2"])

        // Move b3 -> b2
        try p.assert("automatic-0: [r0[b1 ≏ ]] <r0<t3(0,2)>> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![b3 ≏ ≏ ≏ ] <t4(0,1)> ![r0[b2 ≡ 🔵🚂0 ]] <r0<t3(1,0)>> ![r0[b1 ≏ ]] <t2(0,1)> <t1(0,1),l> !{s2 ≏ }", ["b1"])

        // Move b2 -> b1
        try p.assert("automatic-0: [r0[b1 🔵🚂0 ≡ ]] <t3(0,2)> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![b3 ≏ ≏ ≏ ] <t4(0,1)> ![b2 ≏ ] <t3(1,0)> ![r0[b1 ≡ 🔵🚂0 ]] <r0<t2(0,1)>> <r0<t1(0,1)>> !{r0{s2 ≏ }}", ["s2"])

        // Move b1 -> s2
        try p.assert("automatic-0: [b1 ≏ ] <t3(0,2)> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![b3 ≏ ≏ ≏ ] <t4(0,1)> ![b2 ≏ ] <t3(1,0)> ![b1 ≏ ] <t2(0,1)> <t1(0,1)> !{r0{s2 ≡ 🔴🚂0 }}", [])
        
        // The train is still running because the route is .endless
        XCTAssertTrue(p.train.managedScheduling)
    }
    
    func testUpdateAutomaticRouteWithReservedTurnout() throws {
        let layout = LayoutLoopWithStation().newLayout()
        let s1 = layout.block(named: "s1")
        let train = layout.trains[0]
        
        // The route will choose "s2" as the arrival block
        var p = try setup(layout: layout, fromBlockId: s1.id, destination: nil, position: .end, routeSteps: ["s1:next", "b1:next", "s2:next"])
        
        try p.layoutController.stop(trainID: train.id, completely: true)

        try p.assert("automatic-0: {r0{s1 ≏ 💺0 ≏ 🔴🚂0 }} <t1{sr}(0,1),s> <t2{sr}(0,1),s> [b1 ≏ ≏ ] <t4{sl}(1,0),s> {s2 ≏ ≏ }")

        // Let's artifically reserve turnout t2. This should cause the automatic route to be re-evaluated to find an alternate path
        layout.turnout(named: "t2").reserved = .init(train: .init(uuid: "7"), sockets: .init(fromSocketId: 0, toSocketId: 1))
        
        p = try setup(layout: layout, fromBlockId: s1.id, destination: nil, position: .end, routeSteps: ["s1:next", "b2:next", "b3:next", "s2:next"])

        try p.assert("automatic-0: {r0{s1 ≏ 💺0 ≏ 🔵🚂0 }} <r0<t1{sr}(0,2),r>> [r0[b2 ≏ ≏ ]] <t3{sr}(1,0),s> [b3 ≏ ≏ ] <t4{sl}(2,0),s> {s2 ≏ ≏ }")
    }

    func testUpdateAutomaticRouteWithBlockToAvoid() throws {
        let layout = LayoutComplexLoop().newLayout()
        let s1 = layout.block(for: Identifier<Block>(uuid: "s1"))!
        let train = layout.trains[0]
        
        // The route will choose "s2" as the arrival block
        var p = try setup(layout: layout, fromBlockId: s1.id, destination: nil, position: .end, routeSteps: ["s1:next", "b1:next", "b2:next", "b3:next", "s2:next"])
        try p.layoutController.stop(trainID: train.id, completely: true)
        
        // Let's mark "s2" as to avoid
        train.blocksToAvoid.append(.init(Identifier<Block>(uuid: "s2")))

        // The route will choose "s1" instead
        p = try setup(layout: layout, fromBlockId: s1.id, destination: nil, position: .end, routeSteps: ["s1:next", "b1:next", "b2:next", "b3:next", "s1:next"])
        try p.layoutController.stop(trainID: train.id, completely: true)

        // Now let's mark also "s1" as to avoid
        train.blocksToAvoid.append(.init(Identifier<Block>(uuid: "s1")))

        // There will be no possible route to find
        p = try setup(layout: layout, fromBlockId: s1.id, destination: nil, position: .end, routeSteps: [])
        XCTAssertEqual(p.route.steps.count, 0)
    }
    
    func testAutomaticRouteWithTurnoutToAvoid() throws {
        let layout = LayoutComplexLoop().newLayout()
        let s1 = layout.block(for: Identifier<Block>(uuid: "s1"))!

        // The route will choose "s2" as the arrival block
        var p = try setup(layout: layout, fromBlockId: s1.id, destination: nil, position: .end, routeSteps: ["s1:next", "b1:next", "b2:next", "b3:next", "s2:next"])
        try p.layoutController.stop(trainID: layout.trains[0].id, completely: true)
        
        // Let's mark "t5" as to avoid
        layout.trains[0].turnoutsToAvoid.append(.init(Identifier<Turnout>(uuid: "t5")))

        // No route is possible with t5 to avoid
        p = try setup(layout: layout, fromBlockId: s1.id, destination: nil, position: .end, routeSteps: [])
        XCTAssertEqual(p.route.steps.count, 0)
    }

    // This test ensures that the algorithm finds an alternative free path when multiple paths are available
    // to reach the same block but one of the path is reserved. LayoutF will be used with the following scenario:
    // OL3 to NE3:
    // There are two direct paths that exist:
    // (1) OL3 > F.3 > F.1 > F.2 > M.1 > C.1 > C.3 > NE3
    // (2) OL3 > F.3 > F.1 > F.2 > C.3 > NE3
    // Path (1) is chosen first because it is the most natural one.
    // However, if M.1 is reserved, for example, then path (2) should be found.
    func testAutomaticRouteWithAlternateRoute() throws {
        let layout = LayoutComplex().newLayout()
        
        let train = layout.trains[0]
        let ol3 = layout.block("OL3")
        let ne3 = layout.block("NE3")

        let routeId = Route.automaticRouteId(for: train.id)
        let route = layout.route(for: routeId, trainId: train.id)!
        route.steps = [.block(RouteStepBlock(ol3, .next)), .block(RouteStepBlock(ne3, .next))]

        let m1 = layout.turnout("M.1")
        m1.reserved = .init(train: Identifier<Train>(uuid: "foo"), sockets: nil)

        let p = try setup(layout: layout, fromBlockId: ol3.id, destination: .init(ne3.id, direction: .next), position: .end, routeSteps: ["OL3:next", "NE3:next"])
        try p.assert("automatic-16390: [r16390[OL3 💺16390 ≏ 💺16390 ≏ 🔵🚂16390 ]] <r16390<F.3{sr}(0,1),s>> <r16390<F.1{sr}(0,1),s>> <r16390<F.2{sr}(0,2),r>> <r16390<C.3{sr}(1,0),s>> {r16390{NE3 ≏ ≏ }}")
    }

    func testAutomaticRouteNoRouteToSiding() throws {
        let layout = LayoutPointToPoint().newLayout()

        // There is no automatic route possible because there are no stations but only two siding blocks at each end of the route.
        // This will be supported in the future for certain type of train.
        let p = try setup(layout: layout, fromBlockId: Identifier<Block>(uuid: "A"), destination: nil, position: .end, routeSteps: [])
        XCTAssertEqual(p.route.steps.count, 0)
    }

    func testAutomaticRouteFinishing() throws {
        let layout = LayoutComplexLoop().newLayout()
        let s1 = layout.block(for: Identifier<Block>(uuid: "s1"))!

        let p = try setup(layout: layout, fromBlockId: s1.id, destination: nil, position: .end, routeSteps: ["s1:next", "b1:next", "b2:next", "b3:next", "s2:next"])
        
        try p.assert("automatic-0: {r0{s1 ≏ 🔵🚂0 }} <r0<t1(2,0),l>> <r0<t2(1,0),s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4(1,0)> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")
        try p.assert("automatic-0: {s1 ≏ } <t1(2,0),l> <t2(1,0),s> [r0[b1 ≡ 🔵🚂0 ]] <r0<t3>> [r0[b2 ≏ ]] <t4(1,0)> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")
        try p.assert("automatic-0: {s1 ≏ } <t1(2,0),l> <t2(1,0),s> [b1 ≏ ] <t3> [r0[b2 ≡ 🔵🚂0 ]] <r0<t4(1,0)>> [r0[b3 ≏ ≏ ]] <t5> <t6> {s2 ≏ }")
        
        try layout.finishTrain(p.train.id)
        XCTAssertTrue(p.train.managedFinishingScheduling)

        try p.assert("automatic-0: {s1 ≏ } <t1(2,0),l> <t2(1,0),s> [b1 ≏ ] <t3> [b2 ≏ ] <t4(1,0)> [r0[b3 ≡ 🔵🚂0 ≏ ≏ ]] <r0<t5>> <r0<t6>> {r0{s2 ≏ }}")
        try p.assert("automatic-0: {s1 ≏ } <t1(2,0),l> <t2(1,0),s> [b1 ≏ ] <t3> [b2 ≏ ] <t4(1,0)> [r0[b3 ≏ ≡ 🔵🚂0 ≏ ]] <r0<t5>> <r0<t6>> {r0{s2 ≏ }}")
        try p.assert("automatic-0: {s1 ≏ } <t1(2,0),l> <t2(1,0),s> [b1 ≏ ] <t3> [b2 ≏ ] <t4(1,0)> [r0[b3 ≏ ≏ ≡ 🔵🚂0 ]] <r0<t5>> <r0<t6>> {r0{s2 ≏ }}")
        try p.assert("automatic-0: {s1 ≏ } <t1(2,0),l> <t2(1,0),s> [b1 ≏ ] <t3> [b2 ≏ ] <t4(1,0)> [b3 ≏ ≏ ] <t5> <t6> {r0{s2 ≡ 🔴🚂0 }}")

        XCTAssertTrue(p.train.unmanagedScheduling)
    }

    func testFinishingDoesNotStopUntilEndOfRoute() throws {
        let layout = LayoutComplexLoop().newLayout()
        let s1 = layout.block(for: Identifier<Block>(uuid: "s1"))!

        let p = try setup(layout: layout, fromBlockId: s1.id, destination: nil, position: .end, routeSteps: ["s1:next", "b1:next", "b2:next", "b3:next", "s2:next"])
        
        try p.assert("automatic-0: {r0{s1 ≏ 🔵🚂0 }} <r0<t1(2,0),l>> <r0<t2(1,0),s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4(1,0)> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")
                        
        // Let's put another train in b2
        layout.reserve("b2", with: "1", direction: .next)

        // Indicate that we want the train to finish once the route is completed
        try layout.finishTrain(p.train.id)
        XCTAssertTrue(p.train.managedFinishingScheduling)

        try p.assert("automatic-0: {r0{s1 ≏ 🔵🚂0 }} <r0<t1(2,0),l>> <r0<t2(1,0),s>> [r0[b1 ≏ ]] <t3> [r1[b2 ≏ ]] <t4(1,0)> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")
        
        // Move from s1 to b1, the controller will generate a new automatic route because "b2" is occupied.
        try p.assert("automatic-0: [r0[b1 💺0 ≡ 🟡🚂0 ]] <r0<t3{sr}(0,2),r>> ![r0[b5 ≏ ]] <t7{sr}(2,0),s> <t5{sr}(2,0),s> ![b3 ≏ ≏ ≏ ] <t4{sl}(0,1),s> ![r1[b2 ≏ ]] <r0<t3{sr}(1,0),r>> ![r0[b1 🟡🚂0 ≡ 💺0 ]] <t2{sl}(0,1),s> <t1{sl}(0,1),l> !{s2 ≏ }")

        // Move b1 -> b5
        try p.assert("automatic-0: [b1 ≏ ] <t3(0,2),r> ![r0[b5 ≡ 🔵🚂0 ]] <r0<t7(2,0),r>> <r0<t5(2,0),r>> ![r0[b3 ≏ ≏ ]] <t4(0,1)> ![r1[b2 ≏ ]] <t3(1,0),r> ![b1 ≏ ] <t2(0,1)> <t1(0,1),l> !{s2 ≏ }")

        // Let's remove the occupation of b2
        layout.free("b2")
        try p.assert("automatic-0: [b1 ≏ ] <t3(0,2),r> ![r0[b5 ≡ 🔵🚂0 ]] <r0<t7(2,0),r>> <r0<t5(2,0),r>> ![r0[b3 ≏ ≏ ]] <t4(0,1)> ![b2 ≏ ] <t3(1,0),r> ![b1 ≏ ] <t2(0,1)> <t1(0,1),l> !{s2 ≏ }")

        // Move b5 -> b3
        try p.assert("automatic-0: [b1 ≏ ] <t3(0,2),r> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![r0[b3 ≡ 🔵🚂0 ≏ ≏ ]] <r0<t4(0,1)>> ![r0[b2 ≏ ]] <t3(1,0),r> ![b1 ≏ ] <t2(0,1)> <t1(0,1),l> !{s2 ≏ }")
        try p.assert("automatic-0: [b1 ≏ ] <t3(0,2),r> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![r0[b3 ≏ ≡ 🔵🚂0 ≏ ]] <r0<t4(0,1)>> ![r0[b2 ≏ ]] <t3(1,0),r> ![b1 ≏ ] <t2(0,1)> <t1(0,1),l> !{s2 ≏ }")
        try p.assert("automatic-0: [b1 ≏ ] <t3(0,2),r> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![r0[b3 ≏ ≏ ≡ 🔵🚂0 ]] <r0<t4(0,1)>> ![r0[b2 ≏ ]] <t3(1,0),r> ![b1 ≏ ] <t2(0,1)> <t1(0,1),l> !{s2 ≏ }")
        try p.assert("automatic-0: [r0[b1 ≏ ]] <r0<t3(0,2)>> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![b3 ≏ ≏ ≏ ] <t4(0,1)> ![r0[b2 ≡ 🔵🚂0 ]] <r0<t3(1,0)>> ![r0[b1 ≏ ]] <t2(0,1)> <t1(0,1),l> !{s2 ≏ }")
        try p.assert("automatic-0: [r0[b1 🔵🚂0 ≡ ]] <t3(0,2)> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![b3 ≏ ≏ ≏ ] <t4(0,1)> ![b2 ≏ ] <t3(1,0)> ![r0[b1 ≡ 🔵🚂0 ]] <r0<t2(0,1)>> <r0<t1(0,1)>> !{r0{s2 ≏ }}")
        try p.assert("automatic-0: [b1 ≏ ] <t3(0,2)> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![b3 ≏ ≏ ≏ ] <t4(0,1)> ![b2 ≏ ] <t3(1,0)> ![b1 ≏ ] <t2(0,1)> <t1(0,1)> !{r0{s2 ≡ 🔴🚂0 }}")

        // The train has stopped because it has been asked to finish the route
        XCTAssertTrue(p.train.unmanagedScheduling)
    }

    func testAutomaticRouteStationRestart() throws {
        let layout = LayoutComplexLoop().newLayout()
        let s2 = layout.block(for: Identifier<Block>(uuid: "s2"))!

        let p = try setup(layout: layout, fromBlockId: s2.id, destination: nil, position: .end, routeSteps: ["s2:next", "b1:next", "b2:next", "b3:next", "s2:next"])
        
        // Duplicate this test with leading blocks to 2 to see how the speed changes
//        p.train.maxNumberOfLeadingReservedBlocks = 2
        
        try p.assert("automatic-0: {r0{s2 ≏ 🔵🚂0 }} <r0<t1(1,0),s>> <r0<t2(1,0),s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4(1,0)> [b3 ≏ ≏ ] <t5> <t6> {r0{s2 ≏ 🔵🚂0 }}")
        try p.assert("automatic-0: {s2 ≏ } <t1(1,0),s> <t2(1,0),s> [r0[b1 ≡ 🔵🚂0 ]] <r0<t3>> [r0[b2 ≏ ]] <t4(1,0)> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")
        try p.assert("automatic-0: {s2 ≏ } <t1(1,0),s> <t2(1,0),s> [b1 ≏ ] <t3> [r0[b2 ≡ 🔵🚂0 ]] <r0<t4(1,0)>> [r0[b3 ≏ ≏ ]] <t5> <t6> {s2 ≏ }")
        try p.assert("automatic-0: {r0{s2 ≏ }} <t1(1,0),s> <t2(1,0),s> [b1 ≏ ] <t3> [b2 ≏ ] <t4(1,0)> [r0[b3 ≡ 🔵🚂0 ≏ ≏ ]] <r0<t5>> <r0<t6>> {r0{s2 ≏ }}")
        try p.assert("automatic-0: {r0{s2 ≏ }} <t1(1,0),s> <t2(1,0),s> [b1 ≏ ] <t3> [b2 ≏ ] <t4(1,0)> [r0[b3 ≏ ≡ 🔵🚂0 ≏ ]] <r0<t5>> <r0<t6>> {r0{s2 ≏ }}")
        try p.assert("automatic-0: {r0{s2 ≏ }} <t1(1,0),s> <t2(1,0),s> [b1 ≏ ] <t3> [b2 ≏ ] <t4(1,0)> [r0[b3 ≏ ≏ ≡ 🔵🚂0 ]] <r0<t5>> <r0<t6>> {r0{s2 ≏ }}")
        try p.assert("automatic-0: {r0{s2 ≡ 🔴🚂0 }} <t1(1,0),s> <t2(1,0),s> [b1 ≏ ] <t3> [b2 ≏ ] <t4(1,0)> [b3 ≏ ≏ ≏ ] <t5> <t6> {r0{s2 ≡ 🔴🚂0 }}")
                
        // Artificially set the restart time to 0 which will make the train restart again
        p.layoutController.restartTimerFired(layout.trains[0])

        XCTAssertTrue(p.train.speed.requestedKph > 0)
        
        // When restarting, the train automatic route will be updated
        XCTAssertEqual(p.route.steps.toStrings(layout), ["s2:next", "b1:next", "b2:next", "b3:next", "s2:next"])

        // Assert that the train has restarted and is moving in the correct direction
        try p.assert("automatic-0: {r0{s2 ≏ 🔵🚂0 }} <r0<t1(1,0),s>> <r0<t2(1,0),s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4(1,0)> [b3 ≏ ≏ ≏ ] <t5> <t6> {r0{s2 ≏ 🔵🚂0 }}")
        try p.assert("automatic-0: {s2 ≏ } <t1(1,0),s> <t2(1,0),s> [r0[b1 ≡ 🔵🚂0 ]] <r0<t3>> [r0[b2 ≏ ]] <t4(1,0)> [b3 ≏ ≏ ≏ ] <t5> <t6> {s2 ≏ }")
    }
    
    func testAutomaticRouteStationRestartFinishing() throws {
        let layout = LayoutComplexLoop().newLayout()
        let s2 = layout.block(for: Identifier<Block>(uuid: "s2"))!

        let p = try setup(layout: layout, fromBlockId: s2.id, destination: nil, position: .end, routeSteps: ["s2:next", "b1:next", "b2:next", "b3:next", "s2:next"])
        
        try p.assert("automatic-0: {r0{s2 ≏ 🔵🚂0 }} <r0<t1(1,0),s>> <r0<t2(1,0),s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4(1,0)> [b3 ≏ ≏ ] <t5> <t6> {r0{s2 ≏ 🔵🚂0 }}")
        try p.assert("automatic-0: {s2 ≏ } <t1(1,0),s> <t2(1,0),s> [r0[b1 ≡ 🔵🚂0 ]] <r0<t3>> [r0[b2 ≏ ]] <t4(1,0)> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")
        try p.assert("automatic-0: {s2 ≏ } <t1(1,0),s> <t2(1,0),s> [b1 ≏ ] <t3> [r0[b2 ≡ 🔵🚂0 ]] <r0<t4(1,0)>> [r0[b3 ≏ ≏ ]] <t5> <t6> {s2 ≏ }")
        try p.assert("automatic-0: {r0{s2 ≏ }} <t1(1,0),s> <t2(1,0),s> [b1 ≏ ] <t3> [b2 ≏ ] <t4(1,0)> [r0[b3 ≡ 🔵🚂0 ≏ ≏ ]] <r0<t5>> <r0<t6>> {r0{s2 ≏ }}")
        try p.assert("automatic-0: {r0{s2 ≏ }} <t1(1,0),s> <t2(1,0),s> [b1 ≏ ] <t3> [b2 ≏ ] <t4(1,0)> [r0[b3 ≏ ≡ 🔵🚂0 ≏ ]] <r0<t5>> <r0<t6>> {r0{s2 ≏ }}")
        try p.assert("automatic-0: {r0{s2 ≏ }} <t1(1,0),s> <t2(1,0),s> [b1 ≏ ] <t3> [b2 ≏ ] <t4(1,0)> [r0[b3 ≏ ≏ ≡ 🔵🚂0 ]] <r0<t5>> <r0<t6>> {r0{s2 ≏ }}")
        try p.assert("automatic-0: {r0{s2 ≡ 🔴🚂0 }} <t1(1,0),s> <t2(1,0),s> [b1 ≏ ] <t3> [b2 ≏ ] <t4(1,0)> [b3 ≏ ≏ ≏ ] <t5> <t6> {r0{s2 ≡ 🔴🚂0 }}")
        
        // Simulate the user tapping on the "Finish" button while the timer counts down
        try layout.finishTrain(p.train.id)
        XCTAssertTrue(p.train.managedFinishingScheduling)

        // Artificially set the restart time to 0 which will make the train restart again
        p.layoutController.restartTimerFired(p.train)

        // Make sure the train is not moving because we requested to finish the route!
        XCTAssertTrue(p.train.speed.requestedKph == 0)
        
        // Make sure the route hasn't changed
        XCTAssertEqual(p.route.steps.toStrings(layout), ["s2:next", "b1:next", "b2:next", "b3:next", "s2:next"])
        try p.assert("automatic-0: {r0{s2 ≡ 🔴🚂0 }} <t1(1,0),s> <t2(1,0),s> [b1 ≏ ] <t3> [b2 ≏ ] <t4(1,0)> [b3 ≏ ≏ ≏ ] <t5> <t6> {r0{s2 ≡ 🔴🚂0 }}")
    }
        
    /// Same as ``testAutomaticRouteStationRestartFinishing`` but with a station block with 2 feedbacks (s2) that simulates
    /// a stop that includes a ``TrainEvent/movedInsideBlock`` event which exhibit different code path.
    func testAutomaticRouteStationRestartFinishing2() throws {
        let layout = LayoutLoopWithStation().newLayout()
        let s1 = layout.block(named: "s1")
        
        // The route will choose "s2" as the arrival block
        let p = try setup(layout: layout, fromBlockId: s1.id, destination: nil, position: .end, routeSteps: ["s1:next", "b1:next", "s2:next"])
        
        try p.assert("automatic-0: {r0{s1 ≏ ≏ 🔵🚂0 }} <r0<t1{sr}(0,1),s>> <r0<t2{sr}(0,1),s>> [r0[b1 ≏ ≏ ]] <t4{sl}(1,0),s> {s2 ≏ ≏ }")
        try p.assert("automatic-0: {s1 ≏ ≏ } <t1{sr}(0,1),s> <t2{sr}(0,1),s> [r0[b1 ≡ 🔵🚂0 ≏ ]] <r0<t4{sl}(1,0),s>> {r0{s2 ≏ ≏ }}")
        try p.assert("automatic-0: {s1 ≏ ≏ } <t1{sr}(0,1),s> <t2{sr}(0,1),s> [r0[b1 ≏ ≡ 🔵🚂0 ]] <r0<t4{sl}(1,0),s>> {r0{s2 ≏ ≏ }}")
        try p.assert("automatic-0: {s1 ≏ ≏ } <t1{sr}(0,1),s> <t2{sr}(0,1),s> [b1 ≏ ≏ ] <t4{sl}(1,0),s> {r0{s2 ≡ 🟡🚂0 ≏ }}")
        try p.assert("automatic-0: {s1 ≏ ≏ } <t1{sr}(0,1),s> <t2{sr}(0,1),s> [b1 ≏ ≏ ] <t4{sl}(1,0),s> {r0{s2 ≏ ≡ 🔴🚂0 }}")
        
        // Simulate the user tapping on the "Finish" button while the timer counts down
        try layout.finishTrain(p.train.id)
        XCTAssertTrue(p.train.managedFinishingScheduling)

        // Artificially set the restart time to 0 which will make the train restart again
        p.layoutController.restartTimerFired(p.train)

        // Make sure the train is not moving because we requested to finish the route!
        XCTAssertTrue(p.train.speed.requestedKph == 0)
        
        // Make sure the route hasn't changed
        XCTAssertEqual(p.route.steps.toStrings(layout), ["s1:next", "b1:next", "s2:next"])

        try p.assert("automatic-0: {s1 ≏ ≏ } <t1{sr}(0,1),s> <t2{sr}(0,1),s> [b1 ≏ ≏ ] <t4{sl}(1,0),s> {r0{s2 ≏ ≡ 🔴🚂0 }}")
    }

    func testAutomaticRouteStationRestartCannotUpdateAutomaticRouteImmediately() throws {
        let layout = LayoutComplexLoop().newLayout()
        let s2 = layout.block(for: Identifier<Block>(uuid: "s2"))!

        let p = try setup(layout: layout, fromBlockId: s2.id, destination: nil, position: .end, routeSteps: ["s2:next", "b1:next", "b2:next", "b3:next", "s2:next"])
        
        try p.assert("automatic-0: {r0{s2 ≏ 🔵🚂0 }} <r0<t1(1,0),s>> <r0<t2(1,0),s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4(1,0)> [b3 ≏ ≏ ] <t5> <t6> {r0{s2 ≏ 🔵🚂0 }}")
        try p.assert("automatic-0: {s2 ≏ } <t1(1,0),s> <t2(1,0),s> [r0[b1 ≡ 🔵🚂0 ]] <r0<t3>> [r0[b2 ≏ ]] <t4(1,0)> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")
        try p.assert("automatic-0: {s2 ≏ } <t1(1,0),s> <t2(1,0),s> [b1 ≏ ] <t3> [r0[b2 ≡ 🔵🚂0 ]] <r0<t4(1,0)>> [r0[b3 ≏ ≏ ]] <t5> <t6> {s2 ≏ }")
        try p.assert("automatic-0: {r0{s2 ≏ }} <t1(1,0),s> <t2(1,0),s> [b1 ≏ ] <t3> [b2 ≏ ] <t4(1,0)> [r0[b3 ≡ 🔵🚂0 ≏ ≏ ]] <r0<t5>> <r0<t6>> {r0{s2 ≏ }}")
        try p.assert("automatic-0: {r0{s2 ≏ }} <t1(1,0),s> <t2(1,0),s> [b1 ≏ ] <t3> [b2 ≏ ] <t4(1,0)> [r0[b3 ≏ ≡ 🔵🚂0 ≏ ]] <r0<t5>> <r0<t6>> {r0{s2 ≏ }}")
        try p.assert("automatic-0: {r0{s2 ≏ }} <t1(1,0),s> <t2(1,0),s> [b1 ≏ ] <t3> [b2 ≏ ] <t4(1,0)> [r0[b3 ≏ ≏ ≡ 🔵🚂0 ]] <r0<t5>> <r0<t6>> {r0{s2 ≏ }}")
        try p.assert("automatic-0: {r0{s2 ≡ 🔴🚂0 }} <t1(1,0),s> <t2(1,0),s> [b1 ≏ ] <t3> [b2 ≏ ] <t4(1,0)> [b3 ≏ ≏ ≏ ] <t5> <t6> {r0{s2 ≡ 🔴🚂0 }}")
        
        // Let's add a train in the next block b1 that will prevent the train in s2 from immediately restarting
        try layout.setTrainToBlock(layout.trains[1].id, Identifier<Block>(uuid: "b1"), direction: .next)
        p.layoutController.runControllers(.movedToNextBlock)
        
        // Wait until the train route has been updated (which happens when it restarts)
        p.layoutController.restartTimerFired(layout.trains[0])

        // However, in this situation, the route will be empty because a train is blocking the next block
        XCTAssertEqual(p.route.steps.count, 0)
        
        // Now remove the train from the block b1 in order for the train in s2 to start again properly this time
        try layout.remove(trainID: layout.trains[1].id)
        p.layoutController.runControllers(.movedToNextBlock)

        // When restarting, the train automatic route will be updated
        XCTAssertEqual(p.route.steps.toStrings(layout), ["s2:next", "b1:next", "b2:next", "b3:next", "s2:next"])

        // Assert that the train has restarted and is moving in the correct direction
        try p.assert("automatic-0: {r0{s2 ≏ 🔵🚂0 }} <r0<t1(1,0),s>> <r0<t2(1,0),s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4(1,0)> [b3 ≏ ≏ ] <t5> <t6> {r0{s2 ≏ 🔵🚂0 }}")
        try p.assert("automatic-0: {s2 ≏ } <t1(1,0),s> <t2(1,0),s> [r0[b1 ≡ 🔵🚂0 ]] <r0<t3>> [r0[b2 ≏ ]] <t4(1,0)> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")
    }

    func testAutomaticRouteModeOnce() throws {
        let layout = LayoutComplexLoop().newLayout()

        let s2 = layout.block(for: Identifier<Block>(uuid: "s2"))!
        let b3 = layout.block(for: Identifier<Block>(uuid: "b3"))!

        let p = try setup(layout: layout, fromBlockId: s2.id, destination: Destination(b3.id), routeSteps: ["s2:next", "b1:next", "b2:next", "b3:next"])
        
        try p.assert("automatic-0: {r0{s2 🔵🚂0 ≏ }} <r0<t1(1,0),s>> <r0<t2(1,0),s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4(1,0)> [b3 ≏ ≏ ≏ ]")
        try p.assert("automatic-0: {r0{s2 ≡ 🔵🚂0 }} <r0<t1(1,0),s>> <r0<t2(1,0),s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4(1,0)> [b3 ≏ ≏ ≏ ]")
        try p.assert("automatic-0: {s2 ≏ } <t1(1,0),s> <t2(1,0),s> [r0[b1 ≡ 🔵🚂0 ]] <r0<t3>> [r0[b2 ≏ ]] <t4(1,0)> [b3 ≏ ≏ ≏ ]")
        try p.assert("automatic-0: {s2 ≏ } <t1(1,0),s> <t2(1,0),s> [b1 ≏ ] <t3> [r0[b2 ≡ 🔵🚂0 ]] <r0<t4(1,0)>> [r0[b3 ≏ ≏ ≏ ]]")
        try p.assert("automatic-0: {s2 ≏ } <t1(1,0),s> <t2(1,0),s> [b1 ≏ ] <t3> [b2 ≏ ] <t4(1,0)> [r0[b3 ≡ 🟡🚂0 ≏ ≏ ]]")
        try p.assert("automatic-0: {s2 ≏ } <t1(1,0),s> <t2(1,0),s> [b1 ≏ ] <t3> [b2 ≏ ] <t4(1,0)> [r0[b3 ≏ ≡ 🟡🚂0 ≏ ]]")
        try p.assert("automatic-0: {s2 ≏ } <t1(1,0),s> <t2(1,0),s> [b1 ≏ ] <t3> [b2 ≏ ] <t4(1,0)> [r0[b3 ≏ ≏ ≡ 🔴🚂0 ]]")

        XCTAssertTrue(p.train.unmanagedScheduling)
    }

    func testAutomaticRouteModeOnceWithUnreachableDestinationPosition() throws {
        let layout = LayoutComplexLoop().newLayout()
        let s2 = layout.block(for: Identifier<Block>(uuid: "s2"))!
        let b3 = layout.block(for: Identifier<Block>(uuid: "b3"))!

        // Position 0 is not reachable because when the train enters block b3, it is because the first feedback is detected,
        // which is always position 1. We want to make sure that if that is the case, the TrainController still stops the
        // train when it reaches the end of the block because there is no other block left in the route
        let p = try setup(layout: layout, fromBlockId: s2.id, destination: Destination(b3.id, direction: .next), routeSteps: ["s2:next", "b1:next", "b2:next", "b3:next"])
        
        try p.assert("automatic-0: {r0{s2 🔵🚂0 ≏ }} <r0<t1(1,0),s>> <r0<t2(1,0),s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4(1,0)> [b3 ≏ ≏ ≏ ]")
        try p.assert("automatic-0: {r0{s2 ≡ 🔵🚂0 }} <r0<t1(1,0),s>> <r0<t2(1,0),s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4(1,0)> [b3 ≏ ≏ ≏ ]")
        try p.assert("automatic-0: {s2 ≏ } <t1(1,0),s> <t2(1,0),s> [r0[b1 ≡ 🔵🚂0 ]] <r0<t3>> [r0[b2 ≏ ]] <t4(1,0)> [b3 ≏ ≏ ≏ ]")
        try p.assert("automatic-0: {s2 ≏ } <t1(1,0),s> <t2(1,0),s> [b1 ≏ ] <t3> [r0[b2 ≡ 🔵🚂0 ]] <r0<t4(1,0)>> [r0[b3 ≏ ≏ ≏ ]]")
        try p.assert("automatic-0: {s2 ≏ } <t1(1,0),s> <t2(1,0),s> [b1 ≏ ] <t3> [b2 ≏ ] <t4(1,0)> [r0[b3 ≡ 🟡🚂0 ≏ ≏ ]]")
        try p.assert("automatic-0: {s2 ≏ } <t1(1,0),s> <t2(1,0),s> [b1 ≏ ] <t3> [b2 ≏ ] <t4(1,0)> [r0[b3 ≏ ≡ 🟡🚂0 ≏ ]]")
        try p.assert("automatic-0: {s2 ≏ } <t1(1,0),s> <t2(1,0),s> [b1 ≏ ] <t3> [b2 ≏ ] <t4(1,0)> [r0[b3 ≏ ≏ ≡ 🔴🚂0 ]]")

        XCTAssertTrue(p.train.unmanagedScheduling)
    }

    func testAutomaticRouteModeOnceWithReservedBlock() throws {
        let layout = LayoutComplexLoop().newLayout().removeTrainGeometry()
        let s2 = layout.block(for: Identifier<Block>(uuid: "s2"))!
        let b3 = layout.block(for: Identifier<Block>(uuid: "b3"))!

        let p = try setup(layout: layout, fromBlockId: s2.id, destination: Destination(b3.id), routeSteps: ["s2:next", "b1:next", "b2:next", "b3:next"])
        
        try p.assert("automatic-0: {r0{s2 🔵🚂0 ≏ }} <r0<t1(1,0),s>> <r0<t2(1,0),s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4(1,0)> [b3 ≏ ≏ ≏ ]")
        
        // Let's add a train in the block b2
        try layout.setTrainToBlock(layout.trains[1].id, Identifier<Block>(uuid: "b2"), direction: .next)

        try p.assert("automatic-0: {r0{s2 ≡ 🔵🚂0 }} <r0<t1(1,0),s>> <r0<t2(1,0),s>> [r0[b1 ≏ ]] <t3> [r1[b2 🔴🚂1 ≏ ]] <t4(1,0)> [b3 ≏ ≏ ≏ ]")
        try p.assert("automatic-0: {r0{s2 ≏ 🔵🚂0 }} <r0<t1(1,0),s>> <r0<t2(1,0),s>> [r0[b1 ≏ ]] <t3> [r1[b2 🔴🚂1 ≏ ]] <t4(1,0)> [b3 ≏ ≏ ≏ ]")

        // Move from s2 to b1, the route is also updated because b2 is occupied
        try p.assert("automatic-0: [r0[b1 ≡ 🟡🚂0 ]] <r0<t3{sr}(0,2),r>> ![r0[b5 ≏ ]] <t7{sr}(2,0),s> <t5{sr}(2,0),s> ![b3 ≏ ≏ ≏ ]")

        try p.assert("automatic-0: [b1 ≏ ] <t3(0,2),r> ![r0[b5 ≡ 🔵🚂0 ]] <r0<t7(2,0),r>> <r0<t5(2,0),r>> ![r0[b3 ≏ ≏ ≏ ]]")
        try p.assert("automatic-0: [b1 ≏ ] <t3(0,2),r> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![r0[b3 ≡ 🟡🚂0 ≏ ≏ ]]")
        try p.assert("automatic-0: [b1 ≏ ] <t3(0,2),r> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![r0[b3 ≏ ≡ 🟡🚂0 ≏ ]]")
        try p.assert("automatic-0: [b1 ≏ ] <t3(0,2),r> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![r0[b3 ≏ ≏ ≡ 🔴🚂0 ]]")

        XCTAssertTrue(p.train.unmanagedScheduling)
    }

    func testEmergencyStop() throws {
        let layout = LayoutComplexLoop().newLayout()
        let s1 = layout.block(for: Identifier<Block>(uuid: "s1"))!

        let p = try setup(layout: layout, fromBlockId: s1.id, destination: nil, position: .end, routeSteps: ["s1:next", "b1:next", "b2:next", "b3:next", "s2:next"])
        
        try p.assert("automatic-0: {r0{s1 ≏ 🔵🚂0 }} <r0<t1(2,0),l>> <r0<t2(1,0),s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4(1,0)> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")
        try p.assert("automatic-0: {s1 ≏ } <t1(2,0),l> <t2(1,0),s> [r0[b1 ≡ 🔵🚂0 ]] <r0<t3>> [r0[b2 ≏ ]] <t4(1,0)> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")
        try p.assert("automatic-0: {s1 ≏ } <t1(2,0),l> <t2(1,0),s> [b1 ≏ ] <t3> [r0[b2 ≡ 🔵🚂0 ]] <r0<t4(1,0)>> [r0[b3 ≏ ≏ ]] <t5> <t6> {s2 ≏ }")
        
        // Trigger an unexpected feedback so the LayoutController does an emergency stop
        try p.assert("automatic-0: {s1 ≡ } <t1(2,0),l> <t2(1,0),s> [b1 ≏ ] <t3> [r0[b2 ≏ 🔴🚂0 ]] <t4(1,0)> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")
        try p.assert("automatic-0: {s1 ≡ } <t1(2,0),l> <t2(1,0),s> [b1 ≏ ] <t3> [r0[b2 ≏ 🔴🚂0 ]] <t4(1,0)> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")
        try p.assert("automatic-0: {s1 ≡ } <t1(2,0),l> <t2(1,0),s> [b1 ≏ ] <t3> [r0[b2 ≏ 🔴🚂0 ]] <t4(1,0)> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")

        // The train must be in stopped state
        XCTAssertTrue(p.train.unmanagedScheduling)
    }

    // MARK: -- Utility
    
    // Convenience structure to test the layout and its route
    private struct Package {
        let layout: Layout
        let train: Train
        let route: Route
        let asserter: LayoutAsserter
        let layoutController: LayoutController
        
        func assert(_ routeString: String, _ leadingBlockNames: [String]? = nil) throws {
            try asserter.assert([routeString], trains: [train])
            if let leadingBlockNames = leadingBlockNames {
                XCTAssertEqual(train.leadingBlocks.toStrings(), leadingBlockNames)
            }
        }
        
        func toggle(_ feedback: String) {
            layout.feedback(for: Identifier<Feedback>(uuid: feedback))?.detected.toggle()
            layoutController.runControllers(.feedbackTriggered)
        }
    }
    
    private func setup(layout: Layout, fromBlockId: Identifier<Block>, destination: Destination?, position: Position = .start, routeSteps: [String]) throws -> Package {
        let train = layout.trains[0]
        try layout.setTrainToBlock(train.id, fromBlockId, position: position, direction: .next)
        XCTAssertEqual(train.speed.requestedKph, 0)

        layout.automaticRouteRandom = false
                
        // Start the route
        let routeId = Route.automaticRouteId(for: train.id)
        let layoutController = LayoutController(layout: layout, switchboard: nil, interface: MarklinInterface())
        try layoutController.start(routeID: routeId, trainID: train.id, destination: destination)

        let route = layout.route(for: routeId, trainId: train.id)!
        XCTAssertEqual(route.steps.toStrings(layout), routeSteps)
        XCTAssertTrue(train.managedScheduling)

        let asserter = LayoutAsserter(layout: layout, layoutController: layoutController)
        
        return Package(layout: layout, train: train, route: route, asserter: asserter, layoutController: layoutController)
    }
    
}
