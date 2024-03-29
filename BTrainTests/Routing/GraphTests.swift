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

@testable import BTrain
import XCTest

class GraphTests: XCTestCase {
    func constraints(layout: Layout) -> PathFinder.Constraints {
        .init(layout: layout, train: layout.trains[0], reservedBlockBehavior: .ignoreReserved, stopAtFirstBlock: false, relaxed: true)
    }

    private func pathFinder(layout: Layout) -> PathFinder {
        PathFinder(constraints: constraints(layout: layout),
                   settings: .init(verbose: false, random: false, overflow: layout.pathFinderOverflowLimit))
    }

    func testSimplePath() throws {
        let layout = LayoutLoop1().newLayout()
        let b1 = layout.block("b1")
        let b3 = layout.block("b3")

        let gf = pathFinder(layout: layout)
        let p = gf.path(graph: layout, from: b1, to: b3)!
        XCTAssertEqual(p.toStrings, ["b1:1", "0:t0:1", "0:b2:1", "0:t1:2", "0:b3"])
    }

    func testSimplePathBetweenTwoElements() throws {
        let layout = LayoutLoop1().newLayout()
        let b1 = layout.block("b1")
        let b2 = layout.block("b2")

        let gf = pathFinder(layout: layout)
        let p = gf.path(graph: layout, from: GraphPathElement.starting(b1, 1), to: GraphPathElement.ending(b2, 0))!
        XCTAssertEqual(p.toStrings, ["b1:1", "0:t0:1", "0:b2"])
    }

    func testSimplePathBetweenBlockAndTurnout() throws {
        let layout = LayoutLoop1().newLayout()
        let b1 = layout.block("b1")
        let t0 = layout.turnout("t0")

        let gf = pathFinder(layout: layout)
        let p = gf.path(graph: layout, from: GraphPathElement.starting(b1, 1), to: GraphPathElement.ending(t0, 0))!
        XCTAssertEqual(p.toStrings, ["b1:1", "0:t0"])
    }

    func testResolveSimplePath() throws {
        let layout = LayoutLoop1().newLayout()
        let b1 = layout.block("b1")
        let b3 = layout.block("b3")

        let partialPath = [GraphPathElement.starting(b1, 1), GraphPathElement.ending(b3, 0)]

        let gr = pathFinder(layout: layout)
        let p = try gr.resolve(graph: layout, partialPath).get().randomElement()!
        XCTAssertEqual(p.toStrings, ["b1:1", "0:t0:1", "0:b2:1", "0:t1:2", "0:b3"])
    }

    func testResolveSimplePathWithTurnout() throws {
        let layout = LayoutLoop1().newLayout()
        let b1 = layout.block("b1")
        let b3 = layout.block("b3")

        let t0 = layout.turnouts[Identifier<Turnout>(uuid: "t0")]!

        let partialPath = [GraphPathElement.starting(b1, 1), GraphPathElement.between(t0, 0, 1), GraphPathElement.ending(b3, 0)]

        let gr = pathFinder(layout: layout)
        let p = try gr.resolve(graph: layout, partialPath).get().randomElement()!
        XCTAssertEqual(p.toStrings, ["b1:1", "0:t0:1", "0:b2:1", "0:t1:2", "0:b3"])
    }

    func testResolveSimplePathWithTurnouts() throws {
        let layout = LayoutLoop1().newLayout()
        let b1 = layout.block("b1")
        let b3 = layout.block("b3")

        let t0 = layout.turnouts[Identifier<Turnout>(uuid: "t0")]!
        let t1 = layout.turnouts[Identifier<Turnout>(uuid: "t1")]!

        let partialPath = [GraphPathElement.starting(b1, 1), GraphPathElement.between(t0, 0, 1), GraphPathElement.between(t1, 0, 2), GraphPathElement.ending(b3, 0)]

        let gr = pathFinder(layout: layout)
        let p = try gr.resolve(graph: layout, partialPath).get().randomElement()!
        XCTAssertEqual(p.toStrings, ["b1:1", "0:t0:1", "0:b2:1", "0:t1:2", "0:b3"])
    }

    func testResolveSimplePathAlreadyFullPath() throws {
        let layout = LayoutLoop1().newLayout()
        let b1 = layout.block("b1")
        let b3 = layout.block("b3")

        let gf = pathFinder(layout: layout)
        let p = gf.path(graph: layout, from: b1, to: b3)!
        XCTAssertEqual(p.toStrings, ["b1:1", "0:t0:1", "0:b2:1", "0:t1:2", "0:b3"])

        let gr = pathFinder(layout: layout)
        let up = p.elements.map { $0 }
        let p2 = try gr.resolve(graph: layout, up).get().randomElement()!
        XCTAssertEqual(p, p2)
    }

    func testFindPathWithReservedBlock() throws {
        let layout = LayoutLoopWithStation().newLayout()

        // Without block reserved, the straightforward path from s1 to s2 is s1-b1-s2
        var p = try layout.bestPath(from: "s1", toReachBlock: "s2", toDirection: .next, reservedBlockBehavior: .avoidReserved)!
        XCTAssertEqual(p.toStrings, ["0:s1:1", "0:t1:1", "0:t2:1", "0:b1:1", "1:t4:0", "0:s2:1"])

        // Reserve b1 so the algorithm needs to find the alternate route s1-b3-s2
        let b1 = layout.block(named: "b1")
        b1.reservation = .init("foo", .next)

        p = try layout.bestPath(from: "s1", toReachBlock: "s2", toDirection: .next, reservedBlockBehavior: .avoidReserved)!
        XCTAssertEqual(p.toStrings, ["0:s1:1", "0:t1:1", "0:t2:2", "2:t3:0", "0:b3:1", "2:t4:0", "0:s2:1"])
    }

    func testFindPathUntilStation() throws {
        let layout = LayoutLoopWithStation().newLayout()
        layout.automaticRouteRandom = false

        // Do not specify the destination block, so the algorithm will stop at the first station it finds
        let p = try layout.bestPath(from: "s1", reservedBlockBehavior: .avoidReserved)!

        XCTAssertEqual(p.toStrings, ["s1:1", "0:t1:1", "0:t2:1", "0:b1:1", "1:t4:0", "0:s2"])
    }
}
