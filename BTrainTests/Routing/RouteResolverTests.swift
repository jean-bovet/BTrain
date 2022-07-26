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

class RouteResolverTests: XCTestCase {

    func testResolveSimpleRoute() throws {
        let layout = LayoutPointToPoint().newLayout()
        let route = layout.routes[0]
        let train = layout.trains[0]
        
        let resolver = RouteResolver(layout: layout, train: train)
        let resolvedSteps = try resolver.resolve(unresolvedPath: route.steps).get()
        
        XCTAssertEqual(route.steps.toStrings(layout), ["A:next", "B:next", "C:next", "D:next", "E:next"])
        XCTAssertEqual(resolvedSteps.toStrings(layout), ["A:next", "AB:(0>1)", "B:next", "C:next", "D:next", "DE:(1>0)", "E:next"])
    }
    
    func testResolveRouteWithMissingTurnouts() throws {
        let layout = LayoutLoopWithStations().newLayout().removeTrains()
        
        let train = layout.trains[0]
        train.turnoutsToAvoid = []

        let s1 = layout.block(named: "s1")
        let b1 = layout.block(named: "b1")
        let route = layout.newRoute(id: "s1-n1", [(s1.uuid, .next), (b1.uuid, .next)])
        
        let resolver = RouteResolver(layout: layout, train: train)
        
        let resolvedSteps = try resolver.resolve(unresolvedPath: route.steps).get()

        XCTAssertEqual(route.steps.toStrings(layout), ["s1:next", "b1:next"])
        XCTAssertEqual(resolvedSteps.toStrings(layout), ["s1:next", "ts2:(1>0)", "t1:(0>1)", "t2:(0>1)", "b1:next"])
    }

    func testResolveRouteWithMissingBlocks() throws {
        let layout = LayoutLoopWithStations().newLayout().removeTrains()
        
        let train = layout.trains[0]
        train.turnoutsToAvoid = []

        let s1 = layout.block(named: "s1")
        let n1 = layout.block(named: "n1")
        let route = layout.newRoute(id: "s1-n1", [(s1.uuid, .next), (n1.uuid, .next)])
        
        let resolver = RouteResolver(layout: layout, train: train)
        
        let resolvedSteps = try resolver.resolve(unresolvedPath: route.steps).get()

        XCTAssertEqual(route.steps.toStrings(layout), ["s1:next", "n1:next"])
        XCTAssertEqual(resolvedSteps.toStrings(layout), ["s1:next", "ts2:(1>0)", "t1:(0>1)", "t2:(0>1)", "b1:next", "t4:(1>0)", "tn1:(0>1)", "n1:next"])
    }
    
    func testResolveAvoidBlocks() throws {
        let layout = LayoutLoopWithStations().newLayout().removeTrains()
        
        let train = layout.trains[0]
        train.turnoutsToAvoid = []
        
        let s1 = layout.block(named: "s1")
        let n1 = layout.block(named: "n1")
        let route = layout.newRoute(id: "s1-n1", [(s1.uuid, .next), (n1.uuid, .next)])
        
        let resolver = RouteResolver(layout: layout, train: train)
        
        let b1 = layout.block(named: "b1")
        train.blocksToAvoid = [.init(b1.id)]
        
        let resolvedSteps = try resolver.resolve(unresolvedPath: route.steps).get()
        XCTAssertEqual(route.steps.toStrings(layout), ["s1:next", "n1:next"])
        XCTAssertEqual(resolvedSteps.toStrings(layout), ["s1:next", "ts2:(1>0)", "t1:(0>1)", "t2:(0>2)", "t3:(2>0)", "b3:next", "t4:(2>0)", "tn1:(0>1)", "n1:next"])
    }

    func testResolveAvoidTurnouts() throws {
        let layout = LayoutLoopWithStations().newLayout().removeTrains()
        
        let train = layout.trains[0]
        train.turnoutsToAvoid = []
        
        let s1 = layout.block(named: "s1")
        let n1 = layout.block(named: "n1")
        let route = layout.newRoute(id: "s1-n1", [(s1.uuid, .next), (n1.uuid, .next)])
        
        let resolver = RouteResolver(layout: layout, train: train)
        
        let t2 = layout.turnout(named: "t2")
        train.turnoutsToAvoid = [.init(t2.id)]
        
        let resolvedSteps = try resolver.resolve(unresolvedPath: route.steps).get()
        XCTAssertEqual(route.steps.toStrings(layout), ["s1:next", "n1:next"])
        XCTAssertEqual(resolvedSteps.toStrings(layout), ["s1:next", "ts2:(1>0)", "t1:(0>2)", "b2:next", "t3:(1>0)", "b3:next", "t4:(2>0)", "tn1:(0>1)", "n1:next"])
    }

    func testResolveRoute() throws {
        let layout = LayoutLoop2().newLayout()
        let train = layout.trains[0]
        
        let b3 = layout.block("b3")
        b3.reservation = .init("foo", .next)
        
        let route = layout.newRoute(id: "route-1", [("b1", .next), ("b2", .next), ("b3", .next), ("b4", .next), ("b1", .next)])

        let resolver = RouteResolver(layout: layout, train: train)
        let resolvedSteps = try resolver.resolve(unresolvedPath: route.steps).get()

        XCTAssertEqual(resolvedSteps.toStrings(layout), ["b1:next", "t0:(0>1)", "b2:next", "b3:next", "t1:(0>1)", "b4:next", "b1:next"])
    }
}
