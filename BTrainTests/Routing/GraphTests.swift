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

class GraphTests: XCTestCase {

    func testSimplePath() throws {
        let layout = LayoutACreator().newLayout()
        let b1 = layout.block("b1")
        let b3 = layout.block("b3")

        let gf = GraphPathFinder()
        let p = gf.path(graph: layout, from: b1, to: b3)!
        XCTAssertEqual(p.description, ["b1:1", "0:t0:1", "0:b2:1", "0:t1:2", "0:b3"])
    }

    func testSimplePathBetweenTwoElements() throws {
        let layout = LayoutACreator().newLayout()
        let b1 = layout.block("b1")
        let b2 = layout.block("b2")

        let gf = GraphPathFinder()
        let p = gf.path(graph: layout, from: GraphPathElement.starting(b1, 1), to: GraphPathElement.ending(b2, 0))!
        XCTAssertEqual(p.description, ["b1:1", "0:t0:1", "0:b2"])
    }

    func testSimplePathBetweenBlockAndTurnout() throws {
        let layout = LayoutACreator().newLayout()
        let b1 = layout.block("b1")
        let t0 = layout.turnout("t0")

        let gf = GraphPathFinder()
        let p = gf.path(graph: layout, from: GraphPathElement.starting(b1, 1), to: GraphPathElement.ending(t0, 0))!
        XCTAssertEqual(p.description, ["b1:1", "0:t0"])
    }

    func testResolveSimplePath() throws {
        let layout = LayoutACreator().newLayout()
        let b1 = layout.block("b1")
        let b3 = layout.block("b3")

        let partialPath = [ GraphPathElement.starting(b1, 1), GraphPathElement.ending(b3, 0) ]

        let gr = GraphPathResolver()
        let p = gr.resolve(graph: layout, partialPath)!
        XCTAssertEqual(p.description, ["b1:1", "0:t0:1", "0:b2:1", "0:t1:2", "0:b3"])
    }

    func testResolveSimplePathWithTurnout() throws {
        let layout = LayoutACreator().newLayout()
        let b1 = layout.block("b1")
        let b3 = layout.block("b3")

        let t0 = layout.turnout(for: Identifier<Turnout>(uuid: "t0"))!

        let partialPath = [ GraphPathElement.starting(b1, 1), GraphPathElement.between(t0, 0, 1), GraphPathElement.ending(b3, 0) ]

        let gr = GraphPathResolver()
        let p = gr.resolve(graph: layout, partialPath)!
        XCTAssertEqual(p.description, ["b1:1", "0:t0:1", "0:b2:1", "0:t1:2", "0:b3"])
    }

    func testResolveSimplePathWithTurnouts() throws {
        let layout = LayoutACreator().newLayout()
        let b1 = layout.block("b1")
        let b3 = layout.block("b3")

        let t0 = layout.turnout(for: Identifier<Turnout>(uuid: "t0"))!
        let t1 = layout.turnout(for: Identifier<Turnout>(uuid: "t1"))!

        let partialPath = [ GraphPathElement.starting(b1, 1), GraphPathElement.between(t0, 0, 1), GraphPathElement.between(t1, 0, 2), GraphPathElement.ending(b3, 0) ]

        let gr = GraphPathResolver()
        let p = gr.resolve(graph: layout, partialPath)!
        XCTAssertEqual(p.description, ["b1:1", "0:t0:1", "0:b2:1", "0:t1:2", "0:b3"])
    }

    func testResolveSimplePathAlreadyFullPath() throws {
        let layout = LayoutACreator().newLayout()
        let b1 = layout.block("b1")
        let b3 = layout.block("b3")

        let gf = GraphPathFinder()
        let p = gf.path(graph: layout, from: b1, to: b3)!
        XCTAssertEqual(p.description, ["b1:1", "0:t0:1", "0:b2:1", "0:t1:2", "0:b3"])
        
        let gr = GraphPathResolver()
        let p2 = gr.resolve(graph: layout, p)!
        XCTAssertEqual(p, p2)
    }

    func testFindPathWithReservedBlock() throws {
        let layout = LayoutICreator().newLayout()
        let s1 = layout.block("s1")
        let s2 = layout.block("s2")
        let b1 = layout.block("b1")
        
        // Without block reserved, the straighforward path from s1 to s2 is s1-b1-s2
        var p = layout.path(for: layout.trains[0], from: (s1, .next), to: (s2, .previous))!
        XCTAssertEqual(p.description, ["s1:1", "0:t1:1", "0:t2:1", "0:b1:1", "1:t4:0", "0:s2"])
        
        // Reserve b1 so the algorithm needs to find the alternate route s1-b3-s2
        b1.reserved = .init("foo", .next)
                
        p = layout.path(for: layout.trains[0], from: (s1, .next), to: (s2, .previous))!
        XCTAssertEqual(p.description, ["s1:1", "0:t1:1", "0:t2:2", "2:t3:0", "0:b3:1", "2:t4:0", "0:s2"])
    }

    func testFindPathUntilStation() throws {
        let layout = LayoutICreator().newLayout()
        let s1 = layout.block("s1")
        
        // Do not specify the destination block, so the algorithm will stop at the first station it finds
        let p = layout.path(for: layout.trains[0], from: (s1, .next), to: nil)!
        XCTAssertEqual(p.description, ["s1:1", "0:t1:1", "0:t2:1", "0:b1:1", "1:t4:0", "0:s2"])
    }
}

extension Layout {
    
    func block(_ uuid: String) -> Block {
        return block(for: Identifier<Block>(uuid: uuid))!
    }
    
    func turnout(_ uuid: String) -> Turnout {
        return turnout(for: Identifier<Turnout>(uuid: uuid))!
    }
    
    func path(for train: Train, from: (Block, Direction), to: (Block, Direction)?, reservedBlockBehavior: PathFinder.Settings.ReservedBlockBehavior = .avoidReserved) -> GraphPath? {
        let gl = LayoutPathFinder(layout: self, train: train, reservedBlockBehavior: reservedBlockBehavior)
        
        let fromElement = GraphPathElement.starting(from.0, from.1 == .next ? Block.nextSocket : Block.previousSocket)
        let toElement: GraphPathElement?
        if let to = to {
            toElement = .ending(to.0, to.1 == .next ? Block.nextSocket : Block.previousSocket)
        } else {
            toElement = nil
        }
        return gl.path(graph: self, from: fromElement, to: toElement)
    }
}

extension Array where Element == GraphPathElement {
    
    var description: [String] {
        map { pathElement in
            var text = ""
            if let enterSocket = pathElement.enterSocket {
                text += "\(enterSocket):"
            }
            text += pathElement.node.identifier
            if let exitSocket = pathElement.exitSocket {
                text += ":\(exitSocket)"
            }
            return text
        }
    }
}

extension Array where Element == GraphPathElement {
    
    var toSteps: [Route.Step] {
        return self.compactMap { element in
            if let block = element.node as? Block {
                let direction: Direction
                if let entrySocket = element.enterSocket {
                    direction = entrySocket == Block.previousSocket ? .next : .previous
                } else if let exitSocket = element.exitSocket {
                    direction = exitSocket == Block.nextSocket ? .next : .previous
                } else {
                    return nil
                }
                return Route.Step(block, direction)
            } else {
                return nil
            }
        }
    }
}
