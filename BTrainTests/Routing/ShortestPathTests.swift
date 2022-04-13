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
        let path = try DijkstraAlgorithm.shortestPath(graph: layout, from: .starting(s1, Block.nextSocket), to: .ending(s2, Block.previousSocket))
        XCTAssertEqual(path.toStrings, ["0:s1:1", "0:t1:1", "0:t2:1", "0:b1:1", "1:t4:0", "s2:0"])
    }

    func testPath2() throws {
        let layout = LayoutLoopWithStation().newLayout()
        let s1 = layout.block(named: "s1")
        let s2 = layout.block(named: "s2")
        let b1 = layout.block(named: "b1")
        b1.length = 500
        let path = try DijkstraAlgorithm.shortestPath(graph: layout, from: .starting(s1, Block.nextSocket), to: .ending(s2, Block.previousSocket))
        XCTAssertEqual(path.toStrings, ["0:s1:1", "0:t1:1", "0:t2:2", "2:t3:0", "0:b3:1", "2:t4:0", "s2:0"])
    }

}
