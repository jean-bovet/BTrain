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

class PathFinderTests: BTTestCase {
        
    func testSimplePath() throws {
        let layout = LayoutECreator().newLayout()
        let s1 = layout.block(for: Identifier<Block>(uuid: "s1"))!
        let pf = PathFinder(layout: layout)
        
        let settings = PathFinderSettings(random: false, reservedBlockBehavior: .avoidReservedUntil(numberOfSteps: 1), verbose: false)
        let path = try pf.path(trainId: layout.trains[0].id, from: s1, direction: .next, settings: settings)
        XCTAssertNotNil(path)
        XCTAssertEqual(path!.description, ["s1:next", "b1:next", "b2:next", "b3:next", "s2:next"])
    }
    
    func testPathWithBacktrack() throws {
        let layout = LayoutECreator().newLayout()
        let s1 = layout.block(for: Identifier<Block>(uuid: "s1"))!
        let pf = PathFinder(layout: layout)
        pf.turnoutSocketSelectionOverride = { turnout, socketsId, context in
            if turnout.id.uuid == "t5" {
                return 2
            } else {
                return nil
            }
        }

        let settings = PathFinderSettings(random: false, reservedBlockBehavior: .avoidReservedUntil(numberOfSteps: 1), verbose: false)
        let path = try pf.path(trainId: layout.trains[0].id, from: s1, direction: .next, settings: settings)
        XCTAssertNotNil(path)
        XCTAssertEqual(path!.description, ["s1:next", "b1:next", "b2:next", "b3:next", "b5:next", "b1:previous", "s2:previous"])
    }
    
    func testPathLookAhead() throws {
        let layout = LayoutECreator().newLayout()
        let s1 = layout.block(for: Identifier<Block>(uuid: "s1"))!
        let b2 = layout.block(for: Identifier<Block>(uuid: "b2"))!
        b2.reserved = Reservation("other", .next)
        
        let pf = PathFinder(layout: layout)

        // Ensure that by specificy a look ahead equal to the number of blocks in the layout
        // there is no valid path found because b2 is occupied.
        let settings = PathFinderSettings(random: false, reservedBlockBehavior: .avoidReservedUntil(numberOfSteps: 2*layout.blockMap.count), verbose: false)
        var path = try pf.path(trainId: layout.trains[0].id, from: s1, direction: .next, settings: settings)
        XCTAssertNil(path)
        
        // Now let's try again with a look ahead of just one block,
        // in which case the reservation of b2 will be ignored because it is
        // past the look ahead
        let settings2 = PathFinderSettings(random: false, reservedBlockBehavior: .avoidReservedUntil(numberOfSteps: 1), verbose: false)
        path = try pf.path(trainId: layout.trains[0].id, from: s1, direction: .next, settings: settings2)
        XCTAssertNotNil(path)
        XCTAssertEqual(path!.description, ["s1:next", "b1:next", "b2:next", "b3:next", "s2:next"])
    }

    func testPathReserved() throws {
        let layout = LayoutECreator().newLayout()
        let s1 = layout.block(for: Identifier<Block>(uuid: "s1"))!
        let b2 = layout.block(for: Identifier<Block>(uuid: "b2"))!
        b2.reserved = Reservation("other", .next)
        
        let pf = PathFinder(layout: layout)
        pf.turnoutSocketSelectionOverride = { turnout, socketsId, context in
            if turnout.id.uuid == "t4" {
                b2.reserved = nil
            }
            return nil
        }

        let settings = PathFinderSettings(random: false, reservedBlockBehavior: .avoidReservedUntil(numberOfSteps: 2*layout.blockMap.count), verbose: false)
        let path = try pf.path(trainId: layout.trains[0].id, from: s1, direction: .next, settings: settings)
        XCTAssertNotNil(path)
        XCTAssertFalse(path!.context.isOverflowing)
        XCTAssertEqual(path!.description, ["s1:next", "b1:next", "b5:previous", "b3:previous", "b2:previous", "b1:previous", "s2:previous"])
    }

    func testPathDisabled() throws {
        let layout = LayoutECreator().newLayout()
        let s1 = layout.block(for: Identifier<Block>(uuid: "s1"))!
        let b2 = layout.block(for: Identifier<Block>(uuid: "b2"))!
        b2.enabled = false
        
        let pf = PathFinder(layout: layout)
        pf.turnoutSocketSelectionOverride = { turnout, socketsId, context in
            if turnout.id.uuid == "t4" {
                b2.enabled = true
            }
            return nil
        }

        let settings = PathFinderSettings(random: false, reservedBlockBehavior: .avoidReservedUntil(numberOfSteps: 2*layout.blockMap.count), verbose: false)
        let path = try pf.path(trainId: layout.trains[0].id, from: s1, direction: .next, settings: settings)
        XCTAssertNotNil(path)
        XCTAssertFalse(path!.context.isOverflowing)
        XCTAssertEqual(path!.description, ["s1:next", "b1:next", "b5:previous", "b3:previous", "b2:previous", "b1:previous", "s2:previous"])
    }

    func testPathOverflow() throws {
        let layout = LayoutECreator().newLayout()
        let s1 = layout.block(for: Identifier<Block>(uuid: "s1"))!
        
        let pf = PathFinder(layout: layout)
        pf.turnoutSocketSelectionOverride = { turnout, socketsId, context in
            context.visitedSteps.removeAll()
            
            let s1 = layout.block(for: Identifier<Block>(uuid: "s1"))!
            s1.reserved = Reservation("other", .next)

            let s2 = layout.block(for: Identifier<Block>(uuid: "s2"))!
            s2.reserved = Reservation("other", .next)

            return nil
        }

        do {
            let settings = PathFinderSettings(random: false, reservedBlockBehavior: .avoidReservedUntil(numberOfSteps: 2*layout.blockMap.count), verbose: false)
            _ = try pf.path(trainId: layout.trains[0].id, from: s1, direction: .next, settings: settings)
            XCTFail("Exception must be thrown")
        } catch PathFinder.PathError.overflow {
            
        } catch {
            XCTFail("Invalid exception \(error)")
        }
    }

    func testUpdateAutomaticRoute() throws {
        let layout = LayoutECreator().newLayout()
        let s1 = layout.block(for: Identifier<Block>(uuid: "s1"))!

        let train = layout.trains[0]
        train.blockId = s1.id
        s1.train = .init(train.id, .next)
        XCTAssertEqual(train.speed.kph, 0)

        layout.automaticRouteRandom = false
        
        let (success, route) = try layout.updateAutomaticRoute(for: train.id, toBlockId: nil)
        XCTAssertTrue(success)
        XCTAssertEqual(route.steps.description, ["s1:next", "b1:next", "b2:next", "b3:next", "s2:next"])
        XCTAssertFalse(route.enabled)

        // Start the route
        let layoutController = LayoutController(layout: layout, interface: nil)
        try layout.prepare(routeID: route.id, trainID: train.id, startAtEndOfBlock: true)
        try layoutController.start(routeID: route.id, trainID: train.id, toBlockId: nil)
        
        let asserter = LayoutAsserter(layout: layout, layoutController: layoutController)
        
        try asserter.assert(["automatic-0: {r0{s1 ≏ 🚂0 }} <r0<t1,l>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4> [b3 ≏ ] <t5> <t6> {s2 ≏ }"], route: route, trains: [train])
                        
        // Let's put another train in b2
        layout.reserve("b2", with: "1", direction: .next)
        
        try asserter.assert(["automatic-0: {r0{s1 ≏ 🚂0 }} <r0<t1,l>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [r1[b2 ≏ ]] <t4> [b3 ≏ ] <t5> <t6> {s2 ≏ }"], route: route, trains: [train])

        // Move s1 -> b1
        try asserter.assert(["automatic-0: {s1 ≏ } <t1,l> <t2,s> [r0[b1 ≡ 🛑🚂0 ]] <t3> [r1[b2 ≏ ]] <t4> [b3 ≏ ] <t5> <t6> {s2 ≏ }"], route: route, trains: [train])

        // The controller will generate a new automatic route because "b2" is occupied.
        XCTAssertEqual(layoutController.run(), .processed)
        
        // The controller will start the train again because the next block of the new route is free
        XCTAssertEqual(layoutController.run(), .processed)
        
        // Nothing more should happen now
        XCTAssertEqual(layoutController.run(), .none)

        // Because block b2 is occupied, a new route will be generated automatically
        try asserter.assert(["automatic-0: [r0[b1 ≏ 🚂0 ]] <r0<t3(0,2),r>> ![r0[b5 ≏ ]] <t7(2,0)> <t5(2,0)> ![b3 ≏ ] <t4(0,1)> ![r1[b2 ≏ ]] <r0<t3(1,0),r>> ![b1 ≏ ] <t2(0,1)> <t1(0,1),l> !{s2 ≏ }"], route: route, trains: [train])

        // Move b1 -> b5
        try asserter.assert(["automatic-0: [b1 ≏ ] <t3(0,2),r> ![r0[b5 🚂0 ≡ ]] <r0<t7(2,0),r>> <r0<t5(2,0),r>> ![r0[b3 ≏ ]] <t4(0,1)> ![r1[b2 ≏ ]] <t3(1,0),r> ![b1 ≏ ] <t2(0,1)> <t1(0,1),l> !{s2 ≏ }"], route: route, trains: [train])

        // Let's remove the occupation of b2
        layout.free("b2")
        try asserter.assert(["automatic-0: [b1 ≏ ] <t3(0,2),r> ![r0[b5 🚂0 ≡ ]] <r0<t7(2,0),r>> <r0<t5(2,0),r>> ![r0[b3 ≏ ]] <t4(0,1)> ![b2 ≏ ] <t3(1,0),r> ![b1 ≏ ] <t2(0,1)> <t1(0,1),l> !{s2 ≏ }"], route: route, trains: [train])

        // Move b5 -> b3
        try asserter.assert(["automatic-0: [b1 ≏ ] <t3(0,2),r> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![r0[b3 🚂0 ≡ ]] <r0<t4(0,1)>> ![r0[b2 ≏ ]] <t3(1,0),r> ![b1 ≏ ] <t2(0,1)> <t1(0,1),l> !{s2 ≏ }"], route: route, trains: [train])

        // Move b3 -> b2
        try asserter.assert(["automatic-0: [r0[b1 ≏ ]] <r0<t3(0,2)>> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![b3 ≏ ] <t4(0,1)> ![r0[b2 🚂0 ≡ ]] <r0<t3(1,0)>> ![r0[b1 ≏ ]] <t2(0,1)> <t1(0,1),l> !{s2 ≏ }"], route: route, trains: [train])

        // Move b2 -> b1
        try asserter.assert(["automatic-0: [r0[b1 🚂0 ≡ ]] <t3(0,2)> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![b3 ≏ ] <t4(0,1)> ![b2 ≏ ] <t3(1,0)> ![r0[b1 🚂0 ≡ ]] <r0<t2(0,1)>> <r0<t1(0,1)>> !{r0{s2 ≏ }}"], route: route, trains: [train])

        // Move b1 -> s2
        try asserter.assert(["automatic-0: [b1 ≏ ] <t3(0,2)> ![b5 ≏ ] <t7(2,0),r> <t5(2,0),r> ![b3 ≏ ] <t4(0,1)> ![b2 ≏ ] <t3(1,0)> ![b1 ≏ ] <t2(0,1)> <t1(0,1)> !{r0{s2 🛑🚂0 ≡ }}"], route: route, trains: [train])
    }
    
    func testAutomaticRouteStationRestart() throws {
        let layout = LayoutECreator().newLayout()
        let s1 = layout.block(for: Identifier<Block>(uuid: "s2"))!

        let train = layout.trains[0]
        train.blockId = s1.id
        s1.train = .init(train.id, .next)
        XCTAssertEqual(train.speed.kph, 0)

        layout.automaticRouteRandom = false
        
        let (success, route) = try layout.updateAutomaticRoute(for: train.id, toBlockId: nil)
        XCTAssertTrue(success)
        XCTAssertEqual(route.steps.description, ["s2:next", "b1:next", "b2:next", "b3:next", "s2:next"])
        XCTAssertFalse(route.enabled)

        route.stationWaitDuration = 0.250

        // Start the route
        let layoutController = LayoutController(layout: layout, interface: nil)
        try layout.prepare(routeID: route.id, trainID: train.id, startAtEndOfBlock: true)
        try layoutController.start(routeID: route.id, trainID: train.id, toBlockId: nil)
        
        XCTAssertEqual(layoutController.pausedTrainTimers.count, 0)

        let asserter = LayoutAsserter(layout: layout, layoutController: layoutController)
        
        try asserter.assert(["automatic-0: {r0{s2 ≏ 🚂0 }} <r0<t1,s>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4> [b3 ≏ ] <t5> <t6> {s2 ≏ }"], route: route, trains: [train])
        try asserter.assert(["automatic-0: {s2 ≏ } <t1,s> <t2,s> [r0[b1 ≡ 🚂0 ]] <r0<t3>> [r0[b2 ≏ ]] <t4> [b3 ≏ ] <t5> <t6> {s2 ≏ }"], route: route, trains: [train])
        try asserter.assert(["automatic-0: {s2 ≏ } <t1,s> <t2,s> [b1 ≏ ] <t3> [r0[b2 ≡ 🚂0 ]] <r0<t4>> [r0[b3 ≏ ]] <t5> <t6> {s2 ≏ }"], route: route, trains: [train])
        try asserter.assert(["automatic-0: {r0{s2 ≏ }} <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≡ 🚂0 ]] <r0<t5>> <r0<t6>> {r0{s2 ≏ }}"], route: route, trains: [train])
        try asserter.assert(["automatic-0: {r0{s2 ≡ 🛑🚂0 }} <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [b3 ≏ ] <t5> <t6> {r0{s2 ≡ 🛑🚂0 }}"], route: route, trains: [train])
        
        // The train will now wait for `stationWaitDuration` second before starting again
        wait(for: {
            return train.speed.kph > 0
        }, timeout: 1.0)
        
        XCTAssertEqual(layoutController.pausedTrainTimers.count, 0)

        // When restarting, the train automatic route will be updated
        XCTAssertEqual(route.steps.description, ["s2:next", "b1:next", "b2:next", "b3:next", "s2:next"])

        // Assert that the train has restarted and is moving in the correct direction
        try asserter.assert(["automatic-0: {r0{s2 ≏ 🚂0 }} <r0<t1,s>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4> [b3 ≏ ] <t5> <t6> {r0{s2 ≏ 🚂0 }}"], route: route, trains: [train])
        try asserter.assert(["automatic-0: {s2 ≏ } <t1,s> <t2,s> [r0[b1 ≡ 🚂0 ]] <r0<t3>> [r0[b2 ≏ ]] <t4> [b3 ≏ ] <t5> <t6> {s2 ≏ }"], route: route, trains: [train])
    }
    
    func testAutomaticRouteStationRestartCannotUpdateAutomaticRouteImmediately() throws {
        let layout = LayoutECreator().newLayout()
        let s1 = layout.block(for: Identifier<Block>(uuid: "s2"))!

        let train = layout.trains[0]
        train.blockId = s1.id
        s1.train = .init(train.id, .next)
        XCTAssertEqual(train.speed.kph, 0)

        layout.automaticRouteRandom = false
        
        let (success, route) = try layout.updateAutomaticRoute(for: train.id, toBlockId: nil)
        XCTAssertTrue(success)
        XCTAssertEqual(route.steps.description, ["s2:next", "b1:next", "b2:next", "b3:next", "s2:next"])
        XCTAssertFalse(route.enabled)
        route.stationWaitDuration = 0.250

        // Start the route
        let layoutController = LayoutController(layout: layout, interface: nil)
        try layout.prepare(routeID: route.id, trainID: train.id, startAtEndOfBlock: true)
        try layoutController.start(routeID: route.id, trainID: train.id, toBlockId: nil)
        
        XCTAssertEqual(layoutController.pausedTrainTimers.count, 0)

        let asserter = LayoutAsserter(layout: layout, layoutController: layoutController)
        
        try asserter.assert(["automatic-0: {r0{s2 ≏ 🚂0 }} <r0<t1,s>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4> [b3 ≏ ] <t5> <t6> {s2 ≏ }"], route: route, trains: [train])
        try asserter.assert(["automatic-0: {s2 ≏ } <t1,s> <t2,s> [r0[b1 ≡ 🚂0 ]] <r0<t3>> [r0[b2 ≏ ]] <t4> [b3 ≏ ] <t5> <t6> {s2 ≏ }"], route: route, trains: [train])
        try asserter.assert(["automatic-0: {s2 ≏ } <t1,s> <t2,s> [b1 ≏ ] <t3> [r0[b2 ≡ 🚂0 ]] <r0<t4>> [r0[b3 ≏ ]] <t5> <t6> {s2 ≏ }"], route: route, trains: [train])
        try asserter.assert(["automatic-0: {r0{s2 ≏ }} <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≡ 🚂0 ]] <r0<t5>> <r0<t6>> {r0{s2 ≏ }}"], route: route, trains: [train])
        try asserter.assert(["automatic-0: {r0{s2 ≡ 🛑🚂0 }} <t1,s> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [b3 ≏ ] <t5> <t6> {r0{s2 ≡ 🛑🚂0 }}"], route: route, trains: [train])
        
        // Let's add a train in the next block b1 that will prevent the train in s2 from immediately restarting
        try layout.setTrain(layout.trains[1].id, toBlock: Identifier<Block>(uuid: "b1"), direction: .next)
        
        // Wait until the train route has been updated (which happens when it restarts)
        wait(for: {
            return train.routeIndex == 0
        }, timeout: 1.0)
        
        XCTAssertEqual(layoutController.pausedTrainTimers.count, 0)
        
        // However, in this situation, the route will be empty because a train is blocking the next block
        XCTAssertEqual(route.steps.count, 0)
        
        // Now remove the train from the block b1 in order for the train in s2 to start again properly this time
        try layout.free(trainID: layout.trains[1].id, removeFromLayout: true)
        
        layoutController.runControllers()
        
        // When restarting, the train automatic route will be updated
        XCTAssertEqual(route.steps.description, ["s2:next", "b1:next", "b2:next", "b3:next", "s2:next"])

        // Assert that the train has restarted and is moving in the correct direction
        try asserter.assert(["automatic-0: {r0{s2 ≏ 🚂0 }} <r0<t1,s>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4> [b3 ≏ ] <t5> <t6> {r0{s2 ≏ 🚂0 }}"], route: route, trains: [train])
        try asserter.assert(["automatic-0: {s2 ≏ } <t1,s> <t2,s> [r0[b1 ≡ 🚂0 ]] <r0<t3>> [r0[b2 ≏ ]] <t4> [b3 ≏ ] <t5> <t6> {s2 ≏ }"], route: route, trains: [train])
    }

    func testAutomaticRouteBetweenStations() throws {
        let layout = LayoutFCreator().newLayout()
        
        layout.reserve("NE1", with: "1", direction: .next)
        
        let train = layout.trains[0]
        let currentBlock = layout.block(for: Identifier<Block>(uuid: "NE1"))!
        let toBlock = layout.block(for: Identifier<Block>(uuid: "LCF1"))!

        let pf = PathFinder(layout: layout)
        let settings = PathFinderSettings(random: false, reservedBlockBehavior: .avoidReservedUntil(numberOfSteps: 1), verbose: false)
        let path = try pf.path(trainId: train.id, from: currentBlock, toBlock: toBlock, direction: .next, settings: settings)
        XCTAssertNotNil(path)
        XCTAssertEqual(path!.description, ["NE1:next", "OL1:next", "OL2:next", "OL3:next", "NE4:next", "IL1:next", "IL2:next", "IL3:next", "S:next", "IL1:previous", "IL4:previous", "IL3:previous", "IL2:previous", "OL1:previous", "NE3:previous", "M1:next", "M2U:next", "LCF1:next"])
        
        self.measure {
            let path = try! pf.path(trainId: train.id, from: currentBlock, toBlock: toBlock, direction: .next, settings: settings)
            XCTAssertNotNil(path)
        }
    }

    func testAutomaticRouteBetweenStations2() throws {
        let layout = LayoutECreator().newLayout()
        
        layout.reserve("s1", with: "1", direction: .next)
        
        let train = layout.trains[0]
        let currentBlock = layout.block(for: Identifier<Block>(uuid: "s1"))!
        let toBlock = layout.block(for: Identifier<Block>(uuid: "s2"))!

        let pf = PathFinder(layout: layout)
        
        let settings = PathFinderSettings(random: false, reservedBlockBehavior: .avoidReservedUntil(numberOfSteps: 1), verbose: false)
        let path = try pf.path(trainId: train.id, from: currentBlock, toBlock: toBlock, direction: .next, settings: settings)
        XCTAssertEqual(path!.description, ["s1:next", "b1:next", "b2:next", "b3:next", "s2:next"])
    }

    func testShortestPathBetweenStations() throws {
        let layout = LayoutFCreator().newLayout()
        
        layout.reserve("NE1", with: "1", direction: .next)
        
        let train = layout.trains[0]
        let currentBlock = layout.block(for: Identifier<Block>(uuid: "NE1"))!
        let toBlock = layout.block(for: Identifier<Block>(uuid: "HLS_P1"))!

        let pf = PathFinder(layout: layout)
        let settings = PathFinderSettings(random: true, reservedBlockBehavior: .avoidReservedUntil(numberOfSteps: 1), verbose: false)
        
        var generatedPaths = [PathFinder.Path]()
        let path = try pf.path(trainId: train.id, from: currentBlock, toBlock: toBlock, direction: .next, settings: settings) { path in
            generatedPaths.append(path)
        }
        XCTAssertNotNil(path)
        XCTAssertEqual(generatedPaths.count, 10)
        
        generatedPaths.sort { p1, p2 in
            p1.steps.count < p2.steps.count
        }
        let shortestPath = generatedPaths[0]
        print(shortestPath.steps.count)
        XCTAssertEqual(path!.description, shortestPath.description)
    }
}

extension Layout {
    
    func reserve(_ block: String, with train: String, direction: Direction) {
        self.block(for: Identifier<Block>(uuid: block))?.reserved = Reservation(trainId: Identifier<Train>(uuid: train), direction: direction)
    }

    func free(_ block: String) {
        self.block(for: Identifier<Block>(uuid: block))?.reserved = nil
    }

}

extension Array where Element == Route.Step {
    
    var description: [String] {
        return self.map { "\($0.blockId.uuid):\($0.direction.rawValue)" }
    }
}

extension PathFinder.Path {
        
    var description: [String] {
        return steps.description
    }
    
}
