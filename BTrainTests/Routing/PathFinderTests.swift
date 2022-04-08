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
        let s1 = layout.block("s1")
        
        let path = layout.path(for: layout.trains[0], from: (s1, .next), to: nil, reservedBlockBehavior: .avoidFirstReservedBlock)!
        XCTAssertEqual(path.elements.toBlockSteps.description, ["s1:next", "b1:next", "b2:next", "b3:next", "s2:next"])
        XCTAssertEqual(path.elements.toSteps.description, ["s1:next", "t1:(2>0)", "t2:(1>0)", "b1:next", "t3:(0>1)", "b2:next", "t4:(1>0)", "b3:next", "t5:(0>1)", "t6:(0>1)", "s2:next"])
    }
    
    func testPathWithReservedTurnout() throws {
        let layout = LayoutECreator().newLayout()
        let s1 = layout.block("s1")
        let t6 = layout.turnout("t6")
        t6.reserved = .init(train: Identifier<Train>(uuid: "foo"), sockets: nil)
        
        let path = layout.path(for: layout.trains[0], from: (s1, .next), to: nil, reservedBlockBehavior: .avoidReserved)!
        XCTAssertEqual(path.elements.toBlockSteps.description, ["s1:next", "b1:next", "b2:next", "b3:next", "b5:next", "b1:previous", "s2:previous"])
    }
    
    func testPathLookAhead() throws {
        let layout = LayoutECreator().newLayout()
        let s1 = layout.block("s1")
        let b2 = layout.block("b2")
        b2.reserved = Reservation("other", .next)
        
        // Ensure that by specificy a look ahead equal to the number of blocks in the layout
        // there is no valid path found because b2 is occupied.
        let path = layout.path(for: layout.trains[0], from: (s1, .next), to: nil, reservedBlockBehavior: .avoidReserved)
        XCTAssertNil(path)
        
        // Now let's try again with a look ahead of just one block,
        // in which case the reservation of b2 will be ignored because it is
        // past the look ahead
        let path2 = layout.path(for: layout.trains[0], from: (s1, .next), to: nil, reservedBlockBehavior: .avoidFirstReservedBlock)!
        XCTAssertEqual(path2.elements.toBlockSteps.description, ["s1:next", "b1:next", "b2:next", "b3:next", "s2:next"])
    }

    func testPathWithReservedBlock() throws {
        let layout = LayoutICreator().newLayout()
        let s1 = layout.block("s1")
        let b1 = layout.block("b1")
        b1.reserved = Reservation("other", .next)

        var path = layout.path(for: layout.trains[0], from: (s1, .next), to: nil, reservedBlockBehavior: .avoidReserved)!
        XCTAssertEqual(path.elements.toBlockSteps.description, ["s1:next", "b3:next", "s2:next"])
        
        let t2 = layout.turnout("t2")
        t2.reserved = .init(train: Identifier<Train>(uuid: "foo"), sockets: nil)
        
        path = layout.path(for: layout.trains[0], from: (s1, .next), to: nil, reservedBlockBehavior: .avoidReserved)!
        XCTAssertEqual(path.elements.toBlockSteps.description, ["s1:next", "b2:next", "b3:next", "s2:next"])
    }

    func testPathBlockDisabled() throws {
        let layout = LayoutICreator().newLayout()
        let s1 = layout.block("s1")

        var path = layout.path(for: layout.trains[0], from: (s1, .next), to: nil, reservedBlockBehavior: .avoidReserved)!
        XCTAssertEqual(path.elements.toBlockSteps.description, ["s1:next", "b1:next", "s2:next"])
        
        let b1 = layout.block("b1")
        b1.enabled = false
        
        path = layout.path(for: layout.trains[0], from: (s1, .next), to: nil, reservedBlockBehavior: .avoidReserved)!
        XCTAssertEqual(path.elements.toBlockSteps.description, ["s1:next", "b3:next", "s2:next"])
    }

    func testPathTurnoutDisabled() throws {
        let layout = LayoutICreator().newLayout()
        let s1 = layout.block("s1")

        var path = layout.path(for: layout.trains[0], from: (s1, .next), to: nil, reservedBlockBehavior: .avoidReserved)!
        XCTAssertEqual(path.elements.toBlockSteps.description, ["s1:next", "b1:next", "s2:next"])

        let t2 = layout.turnout("t2")
        t2.enabled = false
        
        path = layout.path(for: layout.trains[0], from: (s1, .next), to: nil, reservedBlockBehavior: .avoidReserved)!
        XCTAssertEqual(path.elements.toBlockSteps.description, ["s1:next", "b2:next", "b3:next", "s2:next"])
    }

    func testPathBetweenStations() throws {
        let layout = LayoutFCreator().newLayout()
        
        layout.reserve("NE1", with: "1", direction: .next)
        
        let train = layout.trains[0]
        let ne1 = layout.block("NE1")
        let lcf1 = layout.block("LCF1")

        let path = layout.path(for: train, from: (ne1, .next), to: (lcf1, .next), reservedBlockBehavior: .avoidFirstReservedBlock)!
        XCTAssertEqual(path.elements.toBlockSteps.description, ["NE1:next", "OL1:next", "OL2:next", "OL3:next", "NE4:next", "IL1:next", "IL2:next", "IL3:next", "S:next", "IL1:previous", "IL4:previous", "IL3:previous", "IL2:previous", "OL1:previous", "NE3:previous", "M1:next", "M2U:next", "LCF1:next"])
        
        // Note: by enabling random routing and specifying a destination, the shortest path will be returned
        let shortestPath = layout.path(for: train, from: (ne1, .next), to: (lcf1, .next), reservedBlockBehavior: .avoidFirstReservedBlock, random: true)!
        XCTAssertTrue(shortestPath.elements.toBlockSteps.count < path.elements.toBlockSteps.count)

        self.measure {
            let path = layout.path(for: train, from: (ne1, .next), to: (lcf1, .next), reservedBlockBehavior: .avoidFirstReservedBlock)
            XCTAssertNotNil(path)
        }
    }

    func testPathBetweenStations2() throws {
        let layout = LayoutECreator().newLayout()
        
        layout.reserve("s1", with: "1", direction: .next)
        
        let train = layout.trains[0]
        let s1 = layout.block("s1")
        let s2 = layout.block("s2")

        let path = layout.path(for: train, from: (s1, .next), to: (s2, .next), reservedBlockBehavior: .avoidFirstReservedBlock)!
        XCTAssertEqual(path.elements.toBlockSteps.description, ["s1:next", "b1:next", "b2:next", "b3:next", "s2:next"])
    }
    
    // TODO: investigate why this is so slow
    func testShortestPathBetweenStations() throws {
        let layout = LayoutFCreator().newLayout()
        
        layout.reserve("NE1", with: "1", direction: .next)
        
        let train = layout.trains[0]
        let ne1 = layout.block("NE1")
        let hls_p1 = layout.block("HLS_P1")

        let paths = layout.shortestPaths(for: train, from: (ne1, .next), to: (hls_p1, .next), reservedBlockBehavior: .avoidFirstReservedBlock)
        XCTAssertEqual(paths.count, 10)
        
        for path in paths {
            XCTAssertTrue(path.count >= paths[0].count)
        }
    }

}

extension Layout {
    
    func reserve(_ block: String, with train: String, direction: Direction) {
        self.block(for: Identifier<Block>(uuid: block))?.reserved = Reservation(trainId: Identifier<Train>(uuid: train), direction: direction)
    }

    func free(_ block: String) {
        self.block(for: Identifier<Block>(uuid: block))?.reserved = nil
    }
    
    func path(for train: Train, from: (Block, Direction), to: (Block, Direction)?, reservedBlockBehavior: LayoutPathFinder.ReservedBlockBehavior = .avoidReserved, random: Bool = false) -> GraphPath? {
        let settings = LayoutPathFinder.Settings(reservedBlockBehavior: reservedBlockBehavior, baseSettings: GraphPathFinder.Settings(verbose: false, random: random, overflow: pathFinderOverflowLimit))
        let gl = LayoutPathFinder(layout: self, train: train, settings: settings)
        return path(for: train, from: from, to: to, pathFinder: gl, constraints: gl.constraints)
    }
    
    func shortestPaths(for train: Train, from: (Block, Direction), to: (Block, Direction)?, reservedBlockBehavior: LayoutPathFinder.ReservedBlockBehavior = .avoidReserved) -> [GraphPath] {
        let settings = LayoutPathFinder.Settings(reservedBlockBehavior: reservedBlockBehavior, baseSettings: GraphPathFinder.Settings(verbose: false, random: true, overflow: pathFinderOverflowLimit))
        let gl = LayoutPathFinder(layout: self, train: train, settings: settings)
        
        var paths = [GraphPath]()
        for _ in 1...10 {
            if let path = path(for: train, from: from, to: to, pathFinder: gl, constraints: gl.constraints) {
                paths.append(path)
            }
        }
        paths.sort { p1, p2 in
            p1.count < p2.count
        }
        return paths
    }
    
}

extension Array where Element == Route.Step {
    
    var description: [String] {
        return self.map { $0.description }
    }
}
