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
        
        let settings = PathFinder.Settings(random: false, reservedBlockBehavior: .avoidFirstReservedBlock, verbose: false)
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

        let settings = PathFinder.Settings(random: false, reservedBlockBehavior: .avoidFirstReservedBlock, verbose: false)
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
        let settings = PathFinder.Settings(random: false, reservedBlockBehavior: .avoidReserved, verbose: false)
        var path = try pf.path(trainId: layout.trains[0].id, from: s1, direction: .next, settings: settings)
        XCTAssertNil(path)
        
        // Now let's try again with a look ahead of just one block,
        // in which case the reservation of b2 will be ignored because it is
        // past the look ahead
        let settings2 = PathFinder.Settings(random: false, reservedBlockBehavior: .avoidFirstReservedBlock, verbose: true)
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

        let settings = PathFinder.Settings(random: false, reservedBlockBehavior: .avoidReserved, verbose: false)
        let path = try pf.path(trainId: layout.trains[0].id, from: s1, direction: .next, settings: settings)
        XCTAssertNotNil(path)
        XCTAssertFalse(path!.context.isOverflowing)
        XCTAssertEqual(path!.description, ["s1:next", "b1:next", "b5:previous", "b3:previous", "b2:previous", "b1:previous", "s2:previous"])
    }

    func testPathBlockDisabled() throws {
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

        let settings = PathFinder.Settings(random: false, reservedBlockBehavior: .avoidReserved, verbose: false)
        let path = try pf.path(trainId: layout.trains[0].id, from: s1, direction: .next, settings: settings)
        XCTAssertNotNil(path)
        XCTAssertFalse(path!.context.isOverflowing)
        XCTAssertEqual(path!.description, ["s1:next", "b1:next", "b5:previous", "b3:previous", "b2:previous", "b1:previous", "s2:previous"])
    }

    func testPathTurnoutDisabled() throws {
        let layout = LayoutECreator().newLayout()
        let s1 = layout.block(for: Identifier<Block>(uuid: "s1"))!
        let t4 = layout.turnout(for: Identifier<Turnout>(uuid: "t4"))!
        t4.enabled = false
        
        let pf = PathFinder(layout: layout)
        pf.turnoutSocketSelectionOverride = { turnout, socketsId, context in
            if turnout.id.uuid == "t5" {
                t4.enabled = true
            }
            return nil
        }

        let settings = PathFinder.Settings(random: false, reservedBlockBehavior: .avoidReserved, verbose: false)
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
            let settings = PathFinder.Settings(random: false, reservedBlockBehavior: .avoidReserved, verbose: false)
            _ = try pf.path(trainId: layout.trains[0].id, from: s1, direction: .next, settings: settings)
            XCTFail("Exception must be thrown")
        } catch PathFinder.PathError.overflow {
            
        } catch {
            XCTFail("Invalid exception \(error)")
        }
    }

    func testPathBetweenStations() throws {
        let layout = LayoutFCreator().newLayout()
        
        layout.reserve("NE1", with: "1", direction: .next)
        
        let train = layout.trains[0]
        let currentBlock = layout.block(for: Identifier<Block>(uuid: "NE1"))!
        let destination = Destination(Identifier<Block>(uuid: "LCF1"))
        
        let pf = PathFinder(layout: layout)
        let settings = PathFinder.Settings(random: false, reservedBlockBehavior: .avoidFirstReservedBlock, verbose: false)
        let path = try pf.path(trainId: train.id, from: currentBlock, destination: destination, direction: .next, settings: settings)
        XCTAssertNotNil(path)
        XCTAssertEqual(path!.description, ["NE1:next", "OL1:next", "OL2:next", "OL3:next", "NE4:next", "IL1:next", "IL2:next", "IL3:next", "S:next", "IL1:previous", "IL4:previous", "IL3:previous", "IL2:previous", "OL1:previous", "NE3:previous", "M1:next", "M2U:next", "LCF1:next"])
        
        self.measure {
            let path = try! pf.path(trainId: train.id, from: currentBlock, destination: destination, direction: .next, settings: settings)
            XCTAssertNotNil(path)
        }
    }

    func testPathBetweenStations2() throws {
        let layout = LayoutECreator().newLayout()
        
        layout.reserve("s1", with: "1", direction: .next)
        
        let train = layout.trains[0]
        let currentBlock = layout.block(for: Identifier<Block>(uuid: "s1"))!
        let destination = Destination(Identifier<Block>(uuid: "s2"))

        let pf = PathFinder(layout: layout)
        
        let settings = PathFinder.Settings(random: false, reservedBlockBehavior: .avoidFirstReservedBlock, verbose: false)
        let path = try pf.path(trainId: train.id, from: currentBlock, destination: destination, direction: .next, settings: settings)
        XCTAssertEqual(path!.description, ["s1:next", "b1:next", "b2:next", "b3:next", "s2:next"])
    }

    func testShortestPathBetweenStations() throws {
        let layout = LayoutFCreator().newLayout()
        
        layout.reserve("NE1", with: "1", direction: .next)
        
        let train = layout.trains[0]
        let currentBlock = layout.block(for: Identifier<Block>(uuid: "NE1"))!
        let destination = Destination(Identifier<Block>(uuid: "HLS_P1"))

        let pf = PathFinder(layout: layout)
        let settings = PathFinder.Settings(random: true, reservedBlockBehavior: .avoidFirstReservedBlock, verbose: false)
        
        var generatedPaths = [PathFinder.Path]()
        let path = try pf.path(trainId: train.id, from: currentBlock, destination: destination, direction: .next, settings: settings) { path in
            generatedPaths.append(path)
        }
        XCTAssertNotNil(path)
        XCTAssertEqual(generatedPaths.count, 10)
        
        generatedPaths.sort { p1, p2 in
            p1.steps.count < p2.steps.count
        }
        let shortestPath = generatedPaths[0]
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
        return self.map { $0.description }
    }
}

extension PathFinder.Path {
        
    var description: [String] {
        return steps.description
    }
    
}
