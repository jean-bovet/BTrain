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
        let layout = LayoutECreator().newLayout()
        let s1 = layout.block(for: Identifier<Block>(uuid: "s1"))!

        let p = try setup(layout: layout, fromBlockId: s1.id, destination: nil, position: .end, routeSteps: ["s1:next", "b1:next", "b2:next", "b3:next", "s2:next"])
        
        try p.assert("automatic-0: {r0{s1 ≏ 🚂0 }} <r0<t1,l>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")
                        
        // Let's put another train in b2
        layout.reserve("b2", with: "1", direction: .next)
        
        try p.assert("automatic-0: {r0{s1 ≏ 🚂0 }} <r0<t1,l>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [r1[b2 ≏ ]] <t4> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")

        // Move s1 -> b1
        try p.assert("automatic-0: {s1 ≏ } <t1,l> <t2,s> [r0[b1 ≡ 🛑🚂0 ]] <t3> [r1[b2 ≏ ]] <t4> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")

        // The controller will generate a new automatic route because "b2" is occupied.
        XCTAssertEqual(p.layoutController.run(), .processed)
        
        // The controller will start the train again because the next block of the new route is free
        XCTAssertEqual(p.layoutController.run(), .processed)
        
        // Nothing more should happen now
        XCTAssertEqual(p.layoutController.run(), .none)

        // Because block b2 is occupied, a new route will be generated automatically
        try p.assert("automatic-0: [r0[b1 ≏ 🚂0 ]] <r0<t3(0,2),r>> ![r0[b5 ≏ ]] <t7(2,0)> <t5(2,0)> ![b3 ≏ ≏ ] <t4(0,1)> ![r1[b2 ≏ ]] <r0<t3(1,0),r>> ![b1 ≏ ] <t2(0,1)> <t1(0,1),l> !{s2 ≏ }")

        // Move b1 -> b5
        try p.assert("automatic-0: [b1 ≏ ] <t3(0,2),r> ![r0[b5 🚂0 ≡ ]] <r0<t7(2,0),r>> <r0<t5(2,0),r>> ![r0[b3 ≏ ≏ ]] <t4(0,1)> ![r1[b2 ≏ ]] <t3(1,0),r> ![b1 ≏ ] <t2(0,1)> <t1(0,1),l> !{s2 ≏ }")

        // Let's remove the occupation of b2
        layout.free("b2")
        try p.assert("automatic-0: [b1 ≏ ] <t3(0,2),r> ![r0[b5 🚂0 ≡ ]] <r0<t7(2,0),r>> <r0<t5(2,0),r>> ![r0[b3 ≏ ≏ ]] <t4(0,1)> ![b2 ≏ ] <t3(1,0),r> ![b1 ≏ ] <t2(0,1)> <t1(0,1),l> !{s2 ≏ }")

        // Move b5 -> b3
        try p.assert("automatic-0: [b1 ≏ ] <t3(0,2),r> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![r0[b3 ≏ ≏ 🚂0 ≡ ]] <r0<t4(0,1)>> ![r0[b2 ≏ ]] <t3(1,0),r> ![b1 ≏ ] <t2(0,1)> <t1(0,1),l> !{s2 ≏ }")
        try p.assert("automatic-0: [b1 ≏ ] <t3(0,2),r> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![r0[b3 ≏ 🚂0 ≡ ≏ ]] <r0<t4(0,1)>> ![r0[b2 ≏ ]] <t3(1,0),r> ![b1 ≏ ] <t2(0,1)> <t1(0,1),l> !{s2 ≏ }")
        try p.assert("automatic-0: [b1 ≏ ] <t3(0,2),r> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![r0[b3 🚂0 ≡ ≏ ≏ ]] <r0<t4(0,1)>> ![r0[b2 ≏ ]] <t3(1,0),r> ![b1 ≏ ] <t2(0,1)> <t1(0,1),l> !{s2 ≏ }")

        // Move b3 -> b2
        try p.assert("automatic-0: [r0[b1 ≏ ]] <r0<t3(0,2)>> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![b3 ≏ ≏ ≏ ] <t4(0,1)> ![r0[b2 🚂0 ≡ ]] <r0<t3(1,0)>> ![r0[b1 ≏ ]] <t2(0,1)> <t1(0,1),l> !{s2 ≏ }")

        // Move b2 -> b1
        try p.assert("automatic-0: [r0[b1 🚂0 ≡ ]] <t3(0,2)> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![b3 ≏ ≏ ≏ ] <t4(0,1)> ![b2 ≏ ] <t3(1,0)> ![r0[b1 🚂0 ≡ ]] <r0<t2(0,1)>> <r0<t1(0,1)>> !{r0{s2 ≏ }}")

        // Move b1 -> s2
        try p.assert("automatic-0: [b1 ≏ ] <t3(0,2)> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![b3 ≏ ≏ ≏ ] <t4(0,1)> ![b2 ≏ ] <t3(1,0)> ![b1 ≏ ] <t2(0,1)> <t1(0,1)> !{r0{s2 🛑🚂0 ≡ }}")
        
        // The train is still running because the route is .endless
        XCTAssertTrue(p.train.automaticScheduling)
    }
    
    func testUpdateAutomaticRouteWithBlockToAvoid() throws {
        let layout = LayoutECreator().newLayout()
        let s1 = layout.block(for: Identifier<Block>(uuid: "s1"))!

        // The route will choose "s2" as the arrival block
        var p = try setup(layout: layout, fromBlockId: s1.id, destination: nil, position: .end, routeSteps: ["s1:next", "b1:next", "b2:next", "b3:next", "s2:next"])
        try p.layoutController.stop(trainID: layout.trains[0].id, completely: true)
        
        // Let's mark "s2" as to avoid
        layout.trains[0].blocksToAvoid.append(.init(Identifier<Block>(uuid: "s2")))

        // The route will choose "s1" instead
        p = try setup(layout: layout, fromBlockId: s1.id, destination: nil, position: .end, routeSteps: ["s1:next", "b1:next", "b2:next", "b3:next", "s1:next"])
        try p.layoutController.stop(trainID: layout.trains[0].id, completely: true)

        // Now let's mark also "s1" as to avoid
        layout.trains[0].blocksToAvoid.append(.init(Identifier<Block>(uuid: "s1")))

        // There will be no possible route to find
        _ = try setup(layout: layout, fromBlockId: s1.id, destination: nil, position: .end, routeSteps: [])
    }

    func testUpdateAutomaticRouteFinishing() throws {
        let layout = LayoutECreator().newLayout()
        let s1 = layout.block(for: Identifier<Block>(uuid: "s1"))!

        let p = try setup(layout: layout, fromBlockId: s1.id, destination: nil, position: .end, routeSteps: ["s1:next", "b1:next", "b2:next", "b3:next", "s2:next"])
        
        try p.assert("automatic-0: {r0{s1 ≏ 🚂0 }} <r0<t1,l>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")
        try p.assert("automatic-0: {s1 ≏ } <t1,l> <t2,s> [r0[b1 ≡ 🚂0 ]] <r0<t3>> [r0[b2 ≏ ]] <t4> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")
        try p.assert("automatic-0: {s1 ≏ } <t1,l> <t2,s> [b1 ≏ ] <t3> [r0[b2 ≡ 🚂0 ]] <r0<t4>> [r0[b3 ≏ ≏ ]] <t5> <t6> {s2 ≏ }")
        
        try layout.finishTrain(p.train.id)
        XCTAssertTrue(p.train.automaticFinishingScheduling)

        try p.assert("automatic-0: {s1 ≏ } <t1,l> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≡ 🚂0 ≏ ≏ ]] <r0<t5>> <r0<t6>> {r0{s2 ≏ }}")
        try p.assert("automatic-0: {s1 ≏ } <t1,l> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≏ ≡ 🚂0 ≏ ]] <r0<t5>> <r0<t6>> {r0{s2 ≏ }}")
        try p.assert("automatic-0: {s1 ≏ } <t1,l> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≏ ≏ ≡ 🚂0 ]] <r0<t5>> <r0<t6>> {r0{s2 ≏ }}")
        try p.assert("automatic-0: {s1 ≏ } <t1,l> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ] <t5> <t6> {r0{s2 ≡ 🛑🚂0 }}")

        XCTAssertTrue(p.train.manualScheduling)
    }

    func testAutomaticRouteStationRestart() throws {
        let layout = LayoutECreator().newLayout()
        let s2 = layout.block(for: Identifier<Block>(uuid: "s2"))!

        let p = try setup(layout: layout, fromBlockId: s2.id, destination: nil, position: .end, routeSteps: ["s2:next", "b1:next", "b2:next", "b3:next", "s2:next"])
        
        try p.assert("automatic-0: {r0{s2 ≏ 🚂0 }} <r0<t1,s>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")
        try p.assert("automatic-0: {s2 ≏ } <t1,s> <t2,s> [r0[b1 ≡ 🚂0 ]] <r0<t3>> [r0[b2 ≏ ]] <t4> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")
        try p.assert("automatic-0: {s2 ≏ } <t1,s> <t2,s> [b1 ≏ ] <t3> [r0[b2 ≡ 🚂0 ]] <r0<t4>> [r0[b3 ≏ ≏ ]] <t5> <t6> {s2 ≏ }")
        try p.assert("automatic-0: {r0{s2 ≏ }} <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≡ 🚂0 ≏ ≏ ]] <r0<t5>> <r0<t6>> {r0{s2 ≏ }}")
        try p.assert("automatic-0: {r0{s2 ≏ }} <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≏ ≡ 🚂0 ≏ ]] <r0<t5>> <r0<t6>> {r0{s2 ≏ }}")
        try p.assert("automatic-0: {r0{s2 ≏ }} <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≏ ≏ ≡ 🚂0 ]] <r0<t5>> <r0<t6>> {r0{s2 ≏ }}")
        try p.assert("automatic-0: {r0{s2 ≡ 🛑🚂0 }} <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ≏ ] <t5> <t6> {r0{s2 ≡ 🛑🚂0 }}")
        
        // Nothing should be processed because the timer has not yet expired to restart the train
        XCTAssertEqual(p.layoutController.run(), .none)
        
        // Artificially set the restart time to 0 which will make the train restart again
        layout.trains[0].timeUntilAutomaticRestart = 0
        
        XCTAssertEqual(p.layoutController.run(), .processed) // Automatic route is re-generated
        XCTAssertEqual(p.layoutController.run(), .processed) // Train is re-started
        XCTAssertEqual(p.layoutController.run(), .none)

        XCTAssertTrue(p.train.speed.kph > 0)
        
        // When restarting, the train automatic route will be updated
        XCTAssertEqual(p.route.steps.description, ["s2:next", "b1:next", "b2:next", "b3:next", "s2:next"])

        // Assert that the train has restarted and is moving in the correct direction
        try p.assert("automatic-0: {r0{s2 ≏ 🚂0 }} <r0<t1,s>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ≏ ] <t5> <t6> {r0{s2 ≏ 🚂0 }}")
        try p.assert("automatic-0: {s2 ≏ } <t1,s> <t2,s> [r0[b1 ≡ 🚂0 ]] <r0<t3>> [r0[b2 ≏ ]] <t4> [b3 ≏ ≏ ≏ ] <t5> <t6> {s2 ≏ }")
    }
    
    func testAutomaticRouteStationRestartCannotUpdateAutomaticRouteImmediately() throws {
        let layout = LayoutECreator().newLayout()
        let s2 = layout.block(for: Identifier<Block>(uuid: "s2"))!

        let p = try setup(layout: layout, fromBlockId: s2.id, destination: nil, position: .end, routeSteps: ["s2:next", "b1:next", "b2:next", "b3:next", "s2:next"])
        
        try p.assert("automatic-0: {r0{s2 ≏ 🚂0 }} <r0<t1,s>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")
        try p.assert("automatic-0: {s2 ≏ } <t1,s> <t2,s> [r0[b1 ≡ 🚂0 ]] <r0<t3>> [r0[b2 ≏ ]] <t4> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")
        try p.assert("automatic-0: {s2 ≏ } <t1,s> <t2,s> [b1 ≏ ] <t3> [r0[b2 ≡ 🚂0 ]] <r0<t4>> [r0[b3 ≏ ≏ ]] <t5> <t6> {s2 ≏ }")
        try p.assert("automatic-0: {r0{s2 ≏ }} <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≡ 🚂0 ≏ ≏ ]] <r0<t5>> <r0<t6>> {r0{s2 ≏ }}")
        try p.assert("automatic-0: {r0{s2 ≏ }} <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≏ ≡ 🚂0 ≏ ]] <r0<t5>> <r0<t6>> {r0{s2 ≏ }}")
        try p.assert("automatic-0: {r0{s2 ≏ }} <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≏ ≏ ≡ 🚂0 ]] <r0<t5>> <r0<t6>> {r0{s2 ≏ }}")
        try p.assert("automatic-0: {r0{s2 ≡ 🛑🚂0 }} <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ≏ ] <t5> <t6> {r0{s2 ≡ 🛑🚂0 }}")
        
        // Let's add a train in the next block b1 that will prevent the train in s2 from immediately restarting
        try layout.setTrainToBlock(layout.trains[1].id, Identifier<Block>(uuid: "b1"), direction: .next)
        
        // Wait until the train route has been updated (which happens when it restarts)
        layout.trains[0].timeUntilAutomaticRestart = 0
        XCTAssertEqual(p.layoutController.run(), .none)

        // However, in this situation, the route will be empty because a train is blocking the next block
        XCTAssertEqual(p.route.steps.count, 0)
        
        // Now remove the train from the block b1 in order for the train in s2 to start again properly this time
        try layout.remove(trainID: layout.trains[1].id)
        
        XCTAssertEqual(p.layoutController.run(), .processed) // Automatic route is re-generated
        XCTAssertEqual(p.layoutController.run(), .processed) // Train is re-started
        XCTAssertEqual(p.layoutController.run(), .none)

        // When restarting, the train automatic route will be updated
        XCTAssertEqual(p.route.steps.description, ["s2:next", "b1:next", "b2:next", "b3:next", "s2:next"])

        // Assert that the train has restarted and is moving in the correct direction
        try p.assert("automatic-0: {r0{s2 ≏ 🚂0 }} <r0<t1,s>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ] <t5> <t6> {r0{s2 ≏ 🚂0 }}")
        try p.assert("automatic-0: {s2 ≏ } <t1,s> <t2,s> [r0[b1 ≡ 🚂0 ]] <r0<t3>> [r0[b2 ≏ ]] <t4> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")
    }

    func testAutomaticRouteModeOnce() throws {
        let layout = LayoutECreator().newLayout()
        let s2 = layout.block(for: Identifier<Block>(uuid: "s2"))!
        let b3 = layout.block(for: Identifier<Block>(uuid: "b3"))!

        let p = try setup(layout: layout, fromBlockId: s2.id, destination: Destination(b3.id), routeSteps: ["s2:next", "b1:next", "b2:next", "b3:next"])
        
        try p.assert("automatic-0: {r0{s2 🚂0 ≏ }} <r0<t1,s>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ≏ ]")
        try p.assert("automatic-0: {r0{s2 ≡ 🚂0 }} <r0<t1,s>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ≏ ]")
        try p.assert("automatic-0: {s2 ≏ } <t1,s> <t2,s> [r0[b1 ≡ 🚂0 ]] <r0<t3>> [r0[b2 ≏ ]] <t4> [b3 ≏ ≏ ≏ ]")
        try p.assert("automatic-0: {s2 ≏ } <t1,s> <t2,s> [b1 ≏ ] <t3> [r0[b2 ≡ 🚂0 ]] <r0<t4>> [r0[b3 ≏ ≏ ≏ ]]")
        try p.assert("automatic-0: {s2 ≏ } <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≡ 🚂0 ≏ ≏ ]]")
        try p.assert("automatic-0: {s2 ≏ } <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≏ ≡ 🟨🚂0 ≏ ]]")
        try p.assert("automatic-0: {s2 ≏ } <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≏ ≏ ≡ 🛑🚂0 ]]")

        XCTAssertTrue(p.train.manualScheduling)

        // Nothing more should happen because the automatic route has finished (mode .once)
        XCTAssertEqual(p.layoutController.run(), .none)
        XCTAssertEqual(p.layoutController.run(), .none)
    }

    func testAutomaticRouteModeOnceWithDestinationPosition() throws {
        let layout = LayoutECreator().newLayout()
        let s2 = layout.block(for: Identifier<Block>(uuid: "s2"))!
        let b3 = layout.block(for: Identifier<Block>(uuid: "b3"))!

        // TODO: the position is not used anymore for the destination so either revise this test or remove it
        let p = try setup(layout: layout, fromBlockId: s2.id, destination: Destination(b3.id, direction: .next), routeSteps: ["s2:next", "b1:next", "b2:next", "b3:next"])
        
        try p.assert("automatic-0: {r0{s2 🚂0 ≏ }} <r0<t1,s>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ≏ ]")
        try p.assert("automatic-0: {r0{s2 ≡ 🚂0 }} <r0<t1,s>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ≏ ]")
        try p.assert("automatic-0: {s2 ≏ } <t1,s> <t2,s> [r0[b1 ≡ 🚂0 ]] <r0<t3>> [r0[b2 ≏ ]] <t4> [b3 ≏ ≏ ≏ ]")
        try p.assert("automatic-0: {s2 ≏ } <t1,s> <t2,s> [b1 ≏ ] <t3> [r0[b2 ≡ 🚂0 ]] <r0<t4>> [r0[b3 ≏ ≏ ≏ ]]")
        try p.assert("automatic-0: {s2 ≏ } <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≡ 🚂0 ≏ ≏ ]]")
        try p.assert("automatic-0: {s2 ≏ } <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≏ ≡ 🟨🚂0 ≏ ]]")
        try p.assert("automatic-0: {s2 ≏ } <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≏ ≏ ≡ 🛑🚂0 ]]")

        XCTAssertTrue(p.train.manualScheduling)

        // Nothing more should happen because the automatic route has finished (mode .once)
        XCTAssertEqual(p.layoutController.run(), .none)
        XCTAssertEqual(p.layoutController.run(), .none)
    }

    func testAutomaticRouteModeOnceWithUnreachableDestinationPosition() throws {
        let layout = LayoutECreator().newLayout()
        let s2 = layout.block(for: Identifier<Block>(uuid: "s2"))!
        let b3 = layout.block(for: Identifier<Block>(uuid: "b3"))!

        // Position 0 is not reachable because when the train enters block b3, it is because the first feedback is detected,
        // which is always position 1. We want to make sure that if that is the case, the TrainController still stops the
        // train when it reaches the end of the block because there is no other block left in the route
        let p = try setup(layout: layout, fromBlockId: s2.id, destination: Destination(b3.id, direction: .next), routeSteps: ["s2:next", "b1:next", "b2:next", "b3:next"])
        
        try p.assert("automatic-0: {r0{s2 🚂0 ≏ }} <r0<t1,s>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ≏ ]")
        try p.assert("automatic-0: {r0{s2 ≡ 🚂0 }} <r0<t1,s>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ≏ ]")
        try p.assert("automatic-0: {s2 ≏ } <t1,s> <t2,s> [r0[b1 ≡ 🚂0 ]] <r0<t3>> [r0[b2 ≏ ]] <t4> [b3 ≏ ≏ ≏ ]")
        try p.assert("automatic-0: {s2 ≏ } <t1,s> <t2,s> [b1 ≏ ] <t3> [r0[b2 ≡ 🚂0 ]] <r0<t4>> [r0[b3 ≏ ≏ ≏ ]]")
        try p.assert("automatic-0: {s2 ≏ } <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≡ 🚂0 ≏ ≏ ]]")
        try p.assert("automatic-0: {s2 ≏ } <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≏ ≡ 🟨🚂0 ≏ ]]")
        try p.assert("automatic-0: {s2 ≏ } <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≏ ≏ ≡ 🛑🚂0 ]]")

        XCTAssertTrue(p.train.manualScheduling)

        // Nothing more should happen because the automatic route has finished (mode .once)
        XCTAssertEqual(p.layoutController.run(), .none)
        XCTAssertEqual(p.layoutController.run(), .none)
    }

    func testAutomaticRouteModeOnceWithReservedBlock() throws {
        let layout = LayoutECreator().newLayout()
        let s2 = layout.block(for: Identifier<Block>(uuid: "s2"))!
        let b3 = layout.block(for: Identifier<Block>(uuid: "b3"))!

        let p = try setup(layout: layout, fromBlockId: s2.id, destination: Destination(b3.id), routeSteps: ["s2:next", "b1:next", "b2:next", "b3:next"])
        
        try p.assert("automatic-0: {r0{s2 🚂0 ≏ }} <r0<t1,s>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ≏ ]")
        
        // Let's add a train in the block b2
        try layout.setTrainToBlock(layout.trains[1].id, Identifier<Block>(uuid: "b2"), direction: .next)

        try p.assert("automatic-0: {r0{s2 ≡ 🚂0 }} <r0<t1,s>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [r1[b2 🛑🚂1 ≏ ]] <t4> [b3 ≏ ≏ ≏ ]")
        try p.assert("automatic-0: {s2 ≏ } <t1,s> <t2,s> [r0[b1 ≡ 🛑🚂0 ]] <t3> [r1[b2 🛑🚂1 ≏ ]] <t4> [b3 ≏ ≏ ≏ ]")
        
        // The automatic route is now updated to find an alternative path
        XCTAssertEqual(p.layoutController.run(), .processed)
        XCTAssertEqual(p.route.steps.description, ["b1:next", "b5:previous", "b3:previous"])

        // And now the train restarts following the new route
        try p.assert("automatic-0: [r0[b1 ≏ 🚂0 ]] <r0<t3,r>> ![r0[b5 ≏ ]] <t7> <t5> ![b3 ≏ ≏ ≏]")
        try p.assert("automatic-0: [b1 ≏ ] <t3,r> ![r0[b5 🚂0 ≡ ]] <r0<t7,r>> <r0<t5,r>> ![r0[b3 ≏ ≏ ≏ ]]")
        try p.assert("automatic-0: [b1 ≏ ] <t3,r> ![b5 ≏ ] <t7,r> <t5,r> ![r0[b3 ≏ ≏ 🚂0 ≡ ]]")
        try p.assert("automatic-0: [b1 ≏ ] <t3,r> ![b5 ≏ ] <t7,r> <t5,r> ![r0[b3 ≏ 🟨🚂0 ≡ ≏ ]]")
        try p.assert("automatic-0: [b1 ≏ ] <t3,r> ![b5 ≏ ] <t7,r> <t5,r> ![r0[b3 🛑🚂0 ≡ ≏ ≏ ]]")

        XCTAssertTrue(p.train.manualScheduling)

        // Nothing more should happen because the automatic route has finished (mode .once)
        XCTAssertEqual(p.layoutController.run(), .none)
        XCTAssertEqual(p.layoutController.run(), .none)
    }

    func testEmergencyStop() throws {
        let layout = LayoutECreator().newLayout()
        let s1 = layout.block(for: Identifier<Block>(uuid: "s1"))!

        let p = try setup(layout: layout, fromBlockId: s1.id, destination: nil, position: .end, routeSteps: ["s1:next", "b1:next", "b2:next", "b3:next", "s2:next"])
        
        try p.assert("automatic-0: {r0{s1 ≏ 🚂0 }} <r0<t1,l>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")
        try p.assert("automatic-0: {s1 ≏ } <t1,l> <t2,s> [r0[b1 ≡ 🚂0 ]] <r0<t3>> [r0[b2 ≏ ]] <t4> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")
        try p.assert("automatic-0: {s1 ≏ } <t1,l> <t2,s> [b1 ≏ ] <t3> [r0[b2 ≡ 🚂0 ]] <r0<t4>> [r0[b3 ≏ ≏ ]] <t5> <t6> {s2 ≏ }")
        
        // Trigger an unexpected feedback so the LayoutController does an emergency stop
        try p.assert("automatic-0: {s1 ≡ } <t1,l> <t2,s> [b1 ≏ ] <t3> [r0[b2 ≏ 🛑🚂0 ]] <t4> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")
        try p.assert("automatic-0: {s1 ≡ } <t1,l> <t2,s> [b1 ≏ ] <t3> [r0[b2 ≏ 🛑🚂0 ]] <t4> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")
        try p.assert("automatic-0: {s1 ≡ } <t1,l> <t2,s> [b1 ≏ ] <t3> [r0[b2 ≏ 🛑🚂0 ]] <t4> [b3 ≏ ≏ ] <t5> <t6> {s2 ≏ }")

        // The train must be in stopped state
        XCTAssertTrue(p.train.manualScheduling)
    }

    // MARK: -- Utility
    
    // Convenience structure to test the layout and its route
    private struct Package {
        let layout: Layout
        let train: Train
        let route: Route
        let asserter: LayoutAsserter
        let layoutController: LayoutController
        
        func assert(_ routeString: String) throws {
            try asserter.assert([routeString], route:route, trains: [train])
        }
    }
    
    private func setup(layout: Layout, fromBlockId: Identifier<Block>, destination: Destination?, position: Position = .start, routeSteps: [String]) throws -> Package {
        let train = layout.trains[0]
        try layout.setTrainToBlock(train.id, fromBlockId, position: position, direction: .next)
        XCTAssertEqual(train.speed.kph, 0)

        layout.automaticRouteRandom = false
                
        // Start the route
        let routeId = Route.automaticRouteId(for: train.id)
        let layoutController = LayoutController(layout: layout, interface: nil)
        try layoutController.start(routeID: routeId, trainID: train.id, destination: destination)

        let route = layout.route(for: routeId, trainId: train.id)!
        XCTAssertEqual(route.steps.description, routeSteps)
        XCTAssertTrue(train.automaticScheduling)

        let asserter = LayoutAsserter(layout: layout, layoutController: layoutController)
        
        return Package(layout: layout, train: train, route: route, asserter: asserter, layoutController: layoutController)
    }
    
}
