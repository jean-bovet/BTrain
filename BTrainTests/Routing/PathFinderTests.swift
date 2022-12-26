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

class PathFinderTests: BTTestCase {
    func testSimplePath() throws {
        let layout = LayoutComplexLoop().newLayout()
        layout.automaticRouteRandom = false

        let path = try layout.bestPath(from: "s1", reservedBlockBehavior: .avoidReserved, shortestPath: true)!
        XCTAssertEqual(path.elements.toBlockSteps.toStrings(layout), ["s1:next", "b1:next", "b2:next", "b3:next", "s2:next"])
        XCTAssertEqual(path.elements.toSteps.toStrings(layout), ["s1:next", "t1:(2>0)", "t2:(1>0)", "b1:next", "t3:(0>1)", "b2:next", "t4:(1>0)", "b3:next", "t5:(0>1)", "t6:(0>1)", "s2:next"])
    }

    func testSimplePathAvoidingFirstReservedBlock() throws {
        let layout = LayoutComplexLoop().newLayout()
        layout.automaticRouteRandom = false

        let path = try layout.bestPath(from: "s1", reservedBlockBehavior: .avoidFirstReservedBlock, shortestPath: true)!
        XCTAssertEqual(path.elements.toBlockSteps.toStrings(layout), ["s1:next", "b1:next", "b2:next", "b3:next", "s2:next"])
        XCTAssertEqual(path.elements.toSteps.toStrings(layout), ["s1:next", "t1:(2>0)", "t2:(1>0)", "b1:next", "t3:(0>1)", "b2:next", "t4:(1>0)", "b3:next", "t5:(0>1)", "t6:(0>1)", "s2:next"])
    }

    func testPathWithReservedTurnout() throws {
        let layout = LayoutComplexLoop().newLayout()
        layout.automaticRouteRandom = false

        let t6 = layout.turnout("t6")
        t6.reserved = .init(train: Identifier<Train>(uuid: "foo"), sockets: nil)

        let path = try layout.bestPath(from: "s1", reservedBlockBehavior: .avoidReserved, shortestPath: true)!
        XCTAssertEqual(path.elements.toBlockSteps.toStrings(layout), ["s1:next", "b1:next", "b2:next", "b3:next", "b5:next", "b1:previous", "s2:previous"])
    }

    func testPathLookAhead() throws {
        let layout = LayoutComplexLoop().newLayout()
        layout.automaticRouteRandom = false

        let b2 = layout.block("b2")
        b2.reservation = Reservation("other", .next)

        // Ensure that by specifying a look ahead equal to the number of blocks in the layout
        // there is no valid path found because b2 is occupied.
        let path = try layout.bestPath(from: "s1", reservedBlockBehavior: .avoidReserved, shortestPath: true)
        XCTAssertNil(path)

        // Now let's try again with a look ahead of just one block,
        // in which case the reservation of b2 will be ignored because it is
        // past the look ahead
        let path2 = try layout.bestPath(from: "s1", reservedBlockBehavior: .avoidFirstReservedBlock, shortestPath: true)!
        XCTAssertEqual(path2.elements.toBlockSteps.toStrings(layout), ["s1:next", "b1:next", "b2:next", "b3:next", "s2:next"])
    }

    func testPathWithReservedBlock() throws {
        let layout = LayoutLoopWithStation().newLayout()
        layout.automaticRouteRandom = false

        let b1 = layout.block(named: "b1")
        b1.reservation = Reservation("other", .next)

        var path = try layout.bestPath(from: "s1", reservedBlockBehavior: .avoidReserved, shortestPath: true)!
        XCTAssertEqual(path.elements.toBlockSteps.toStrings(layout), ["s1:next", "b3:next", "s2:next"])

        let t2 = layout.turnout(named: "t2")
        t2.reserved = .init(train: Identifier<Train>(uuid: "foo"), sockets: nil)

        path = try layout.bestPath(from: "s1", reservedBlockBehavior: .avoidReserved, shortestPath: true)!
        XCTAssertEqual(path.elements.toBlockSteps.toStrings(layout), ["s1:next", "b2:next", "b3:next", "s2:next"])
    }

    func testPathBlockDisabled() throws {
        let layout = LayoutLoopWithStation().newLayout()
        layout.automaticRouteRandom = false

        var path = try layout.bestPath(from: "s1", reservedBlockBehavior: .avoidReserved, shortestPath: true)!
        XCTAssertEqual(path.elements.toBlockSteps.toStrings(layout), ["s1:next", "b1:next", "s2:next"])

        let b1 = layout.block(named: "b1")
        b1.enabled = false

        path = try layout.bestPath(from: "s1", reservedBlockBehavior: .avoidReserved, shortestPath: true)!
        XCTAssertEqual(path.elements.toBlockSteps.toStrings(layout), ["s1:next", "b3:next", "s2:next"])
    }

    func testPathTurnoutDisabled() throws {
        let layout = LayoutLoopWithStation().newLayout()
        layout.automaticRouteRandom = false

        var path = try layout.bestPath(from: "s1", reservedBlockBehavior: .avoidReserved, shortestPath: true)!
        XCTAssertEqual(path.elements.toBlockSteps.toStrings(layout), ["s1:next", "b1:next", "s2:next"])

        let t2 = layout.turnout(named: "t2")
        t2.enabled = false

        path = try layout.bestPath(from: "s1", reservedBlockBehavior: .avoidReserved, shortestPath: true)!
        XCTAssertEqual(path.elements.toBlockSteps.toStrings(layout), ["s1:next", "b2:next", "b3:next", "s2:next"])
    }

    func testPathBetweenStations() throws {
        let layout = LayoutComplex().newLayout().removeTrains()
        layout.automaticRouteRandom = false

        layout.reserve("NE1", with: "1", direction: .next)

        let train = layout.trains[0]

        train.blocksToAvoid = []
        train.turnoutsToAvoid = []

        guard let path = try layout.bestPath(from: "NE1", toReachBlock: "LCF1", toDirection: .next, reservedBlockBehavior: .avoidReserved, shortestPath: false) else {
            XCTFail("Unable to find path from NE1 to LCF1")
            return
        }
        XCTAssertEqual(path.elements.toBlockSteps.toStrings(layout), ["NE1:next", "OL1:next", "OL2:next", "OL3:next", "NE4:next", "IL1:next", "IL2:next", "IL3:next", "S:next", "IL1:previous", "IL4:previous", "IL3:previous", "IL2:previous", "OL1:previous", "NE3:previous", "M1:next", "M2U:next", "LCF1:next"])

        // Now find out the shortest path
        let shortestPath = try layout.bestPath(from: "NE1", toReachBlock: "LCF1", toDirection: .next, reservedBlockBehavior: .avoidReserved, shortestPath: true)!

        XCTAssertTrue(shortestPath.elements.toBlockSteps.count < path.elements.toBlockSteps.count)
        XCTAssertEqual(shortestPath.elements.toBlockSteps.toStrings(layout), ["NE1:next", "IL1:next", "IL2:next", "IL3:next", "S:next", "IL1:previous", "NE4:previous", "M1:next", "M2U:next", "LCF1:next"])

        measure {
            let path = try? layout.bestPath(from: "NE1", toReachBlock: "LCF1", toDirection: .next, reservedBlockBehavior: .avoidReserved, shortestPath: true)
            XCTAssertNotNil(path)
        }
    }

    func testPathBetweenStations2() throws {
        let layout = LayoutComplexLoop().newLayout()
        layout.automaticRouteRandom = false

        layout.reserve("s1", with: "1", direction: .next)

        let path = try layout.bestPath(from: "s1", toReachBlock: "s2", toDirection: .next, reservedBlockBehavior: .avoidReserved, shortestPath: true)!
        XCTAssertEqual(path.elements.toBlockSteps.toStrings(layout), ["s1:next", "b1:next", "b2:next", "b3:next", "s2:next"])
    }

    func testPathBetweenTwoBlocksWithMultipleTurnouts() throws {
        let layout = LayoutComplexWithHiddenStation().newLayout()
        layout.automaticRouteRandom = false

        let path = try layout.bestPath(from: "S3", fromDirection: .previous, toReachBlock: "IL_3", toDirection: .next, reservedBlockBehavior: .avoidReserved, shortestPath: true)!
        XCTAssertEqual(path.elements.toBlockSteps.toStrings(layout), ["S3:previous", "IL_3:next"])

        // Note: ensure the path goes via the turnouts T15-T18-T17 and not via T15-T13-T17 which is a longer initiative.
        XCTAssertEqual(path.elements.toSteps.toStrings(layout), ["S3:previous", "T15:(3>2)", "T18:(0>1)", "T17:(2>0)", "T12:(2>0)", "IL_3:next"])
    }
}
