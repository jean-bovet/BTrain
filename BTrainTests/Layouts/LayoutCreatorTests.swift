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

class LayoutCreatorTests: XCTestCase {

    func testEmptyLayout() {
        let c = LayoutBlankCreator()
        XCTAssertEqual(c.name, "New Layout")
        let layout = c.newLayout()
        XCTAssertEqual(layout.blockMap.count, 0)
    }

    func testLayoutA() {
        let c = LayoutACreator()
        XCTAssertEqual(c.name, "Loop with Reverse")
        
        let layout = c.newLayout()
        XCTAssertEqual(layout.blockMap.count, 3)
    }

    func testLayoutB() {
        let c = LayoutBCreator()
        XCTAssertEqual(c.name, "8-style Loop")
        
        let layout = c.newLayout()
        XCTAssertEqual(layout.blockMap.count, 4)
    }

    func testLayoutC() {
        let c = LayoutCCreator()
        XCTAssertEqual(c.name, "Loop and Diagonal")
        
        let layout = c.newLayout()
        XCTAssertEqual(layout.blockMap.count, 5)
    }

    func testLayoutD() {
        let c = LayoutDCreator()
        XCTAssertEqual(c.name, "Incomplete Layout")
        
        let layout = c.newLayout()
        XCTAssertEqual(layout.blockMap.count, 2)
    }

    func testLayoutE() {
        let c = LayoutECreator()
        XCTAssertEqual(c.name, "Loop with Alternatives")
        
        let layout = c.newLayout()
        XCTAssertEqual(layout.blockMap.count, 8)
    }

    func testLayoutF() {
        let c = LayoutFCreator()
        XCTAssertEqual(c.name, "Complex Layout")
        
        let layout = c.newLayout()
        XCTAssertEqual(layout.blockMap.count, 29)
    }

    func testLayoutG() {
        let c = LayoutGCreator()
        XCTAssertEqual(c.name, "Layout with All Elements")
        
        let layout = c.newLayout()
        XCTAssertEqual(layout.blockMap.count, 8)
    }

}
