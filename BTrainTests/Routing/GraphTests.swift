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

    func testGraph() throws {
        let layout = LayoutACreator().newLayout()
        let b1 = layout.block(for: Identifier<Block>(uuid: "b1"))!
        let b3 = layout.block(for: Identifier<Block>(uuid: "b3"))!
        
        let gf = GraphPathFinder()
        let p = gf.path(graph: layout, from: b1, to: b3)!
        XCTAssertEqual(p.description, ["b1:1", "0:t0:1", "0:b2:1", "0:t1:2", "0:b3"])
    }

    func testGraphResolve() throws {
        let layout = LayoutACreator().newLayout()
        let b1 = layout.block(for: Identifier<Block>(uuid: "b1"))!
        let b3 = layout.block(for: Identifier<Block>(uuid: "b3"))!

        let partialPath = [ GraphPathElement.starting(b1, 1), GraphPathElement.ending(b3, 0) ]

        let gr = GraphPathResolver()
        let p = gr.resolve(graph: layout, partialPath)!
        XCTAssertEqual(p.description, ["b1:1", "0:t0:1", "0:b2:1", "0:t1:2", "0:b3"])
    }

    func testGraphResolveWithTurnout() throws {
        let layout = LayoutACreator().newLayout()
        let b1 = layout.block(for: Identifier<Block>(uuid: "b1"))!
        let b3 = layout.block(for: Identifier<Block>(uuid: "b3"))!

        let t0 = layout.turnout(for: Identifier<Turnout>(uuid: "t0"))!

        let partialPath = [ GraphPathElement.starting(b1, 1), GraphPathElement.between(t0, 0, 1), GraphPathElement.ending(b3, 0) ]

        let gr = GraphPathResolver()
        let p = gr.resolve(graph: layout, partialPath)!
        XCTAssertEqual(p.description, ["b1:1", "0:t0:1", "0:b2:1", "0:t1:2", "0:b3"])
    }

    func testGraphResolveWithTurnouts() throws {
        let layout = LayoutACreator().newLayout()
        let b1 = layout.block(for: Identifier<Block>(uuid: "b1"))!
        let b3 = layout.block(for: Identifier<Block>(uuid: "b3"))!

        let t0 = layout.turnout(for: Identifier<Turnout>(uuid: "t0"))!
        let t1 = layout.turnout(for: Identifier<Turnout>(uuid: "t1"))!

        let partialPath = [ GraphPathElement.starting(b1, 1), GraphPathElement.between(t0, 0, 1), GraphPathElement.between(t1, 0, 2), GraphPathElement.ending(b3, 0) ]

        let gr = GraphPathResolver()
        let p = gr.resolve(graph: layout, partialPath)!
        XCTAssertEqual(p.description, ["b1:1", "0:t0:1", "0:b2:1", "0:t1:2", "0:b3"])
    }

    func testGraphResolveAlreadyFullPath() throws {
        let layout = LayoutACreator().newLayout()
        let b1 = layout.block(for: Identifier<Block>(uuid: "b1"))!
        let b3 = layout.block(for: Identifier<Block>(uuid: "b3"))!
        
        let gf = GraphPathFinder()
        let p = gf.path(graph: layout, from: b1, to: b3)!
        XCTAssertEqual(p.description, ["b1:1", "0:t0:1", "0:b2:1", "0:t1:2", "0:b3"])
        
        let gr = GraphPathResolver()
        let p2 = gr.resolve(graph: layout, p)!
        XCTAssertEqual(p, p2)
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
