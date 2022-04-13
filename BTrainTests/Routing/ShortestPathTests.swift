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

import XCTest

                                                                    
//
//┌─────────┐                      ┌─────────┐             ┌─────────┐
//│   s1    │───▶  t1  ───▶  t2  ─▶│   b1    │─▶  t4  ────▶│   s2    │
//└─────────┘                      └─────────┘             └─────────┘
//     ▲            │         │                    ▲            │
//     │            │         │                    │            │
//     │            ▼         ▼                    │            │
//     │       ┌─────────┐                    ┌─────────┐       │
//     │       │   b2    │─▶ t3  ────────────▶│   b3    │       │
//     │       └─────────┘                    └─────────┘       ▼
//┌─────────┐                                              ┌─────────┐
//│   b5    │◀─────────────────────────────────────────────│   b4    │
//└─────────┘                                              └─────────┘
class ShortestPathTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testPath1() throws {
        let layout = LayoutLoopWithStation().newLayout()
        let s1 = layout.block(named: "s1")
        let s2 = layout.block(named: "s2")
        let path = try DijkstraAlgorithm.shortestPath(graph: layout,
                                                      from: s1.elementDirectionNext,
                                                      to: s2.elementDirectionNext)
        XCTAssertEqual(path.toStrings, ["0:s1:1", "0:t1:1", "0:t2:1", "0:b1:1", "1:t4:0", "0:s2:1"])
    }

    func testPath1Reverse() throws {
        let layout = LayoutLoopWithStation().newLayout()
        let s1 = layout.block(named: "s1")
        let s2 = layout.block(named: "s2")
        let path = try DijkstraAlgorithm.shortestPath(graph: layout,
                                                      from: s2.elementDirectionPrevious,
                                                      to: s1.elementDirectionPrevious)
        XCTAssertEqual(path.toStrings, ["1:s2:0", "0:t4:1", "1:b1:0", "1:t2:0", "1:t1:0", "1:s1:0"])
    }

    func testPath2() throws {
        let layout = LayoutLoopWithStation().newLayout()
        let s1 = layout.block(named: "s1")
        let s2 = layout.block(named: "s2")
        let b1 = layout.block(named: "b1")
        b1.length = 500
        let path = try DijkstraAlgorithm.shortestPath(graph: layout,
                                                      from: s1.elementDirectionNext,
                                                      to: s2.elementDirectionNext)
        XCTAssertEqual(path.toStrings, ["0:s1:1", "0:t1:1", "0:t2:2", "2:t3:0", "0:b3:1", "2:t4:0", "0:s2:1"])
    }

    func testPath2Reverse() throws {
        let layout = LayoutLoopWithStation().newLayout()
        let s1 = layout.block(named: "s1")
        let s2 = layout.block(named: "s2")
        let b1 = layout.block(named: "b1")
        b1.length = 500
        let path = try DijkstraAlgorithm.shortestPath(graph: layout,
                                                      from: s2.elementDirectionPrevious,
                                                      to: s1.elementDirectionPrevious)
        XCTAssertEqual(path.toStrings, ["1:s2:0", "0:t4:2", "1:b3:0", "0:t3:2", "2:t2:0", "1:t1:0", "1:s1:0"])
    }

    func testPath3() throws {
        let layout = LayoutLoopWithStation().newLayout()
        let s1 = layout.block(named: "s1")
        let s2 = layout.block(named: "s2")
        let b1 = layout.block(named: "b1")
        b1.length = 500
        let t2 = layout.turnout(named: "t2")
        t2.length = 200
        let path = try DijkstraAlgorithm.shortestPath(graph: layout,
                                                      from: s1.elementDirectionNext,
                                                      to: s2.elementDirectionNext)
        XCTAssertEqual(path.toStrings, ["0:s1:1", "0:t1:2", "0:b2:1", "1:t3:0", "0:b3:1", "2:t4:0", "0:s2:1"])
    }
    
    func testPath3Reverse() throws {
        let layout = LayoutLoopWithStation().newLayout()
        let s1 = layout.block(named: "s1")
        let s2 = layout.block(named: "s2")
        let b1 = layout.block(named: "b1")
        b1.length = 500
        let t2 = layout.turnout(named: "t2")
        t2.length = 200
        let path = try DijkstraAlgorithm.shortestPath(graph: layout,
                                                      from: s2.elementDirectionPrevious,
                                                      to: s1.elementDirectionPrevious)
        XCTAssertEqual(path.toStrings, ["1:s2:0", "0:t4:2", "1:b3:0", "0:t3:1", "1:b2:0", "2:t1:0", "1:s1:0"])
    }


}
