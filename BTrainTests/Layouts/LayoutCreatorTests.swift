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
        XCTAssertEqual(LayoutBlankCreator.id.uuid, "Empty Layout")
        let layout = LayoutBlankCreator().newLayout()
        XCTAssertEqual(layout.blockMap.count, 0)
    }

    func testLayoutA() {
        XCTAssertEqual(LayoutLoop1.id.uuid, "Loop 1")
        
        let layout = LayoutLoop1().newLayout()
        XCTAssertEqual(layout.blockMap.count, 3)
    }

    func testLayoutB() {
        XCTAssertEqual(LayoutFigure8.id.uuid, "Figure 8")
        
        let layout = LayoutFigure8().newLayout()
        XCTAssertEqual(layout.blockMap.count, 4)
    }

    func testLayoutC() {
        XCTAssertEqual(LayoutLoop2.id.uuid, "Loop 2")
        
        let layout = LayoutLoop2().newLayout()
        XCTAssertEqual(layout.blockMap.count, 5)
    }

    func testLayoutD() {
        XCTAssertEqual(LayoutIncomplete.id.uuid, "Incomplete Layout")
        
        let layout = LayoutIncomplete().newLayout()
        XCTAssertEqual(layout.blockMap.count, 2)
    }

    func testLayoutE() {
        XCTAssertEqual(LayoutComplexLoop.id.uuid, "Complex Loop")
        
        let layout = LayoutComplexLoop().newLayout()
        XCTAssertEqual(layout.blockMap.count, 8)
    }

    func testLayoutF() {
        XCTAssertEqual(LayoutComplex.id.uuid, "Complex Layout")
        
        let layout = LayoutComplex().newLayout()
        XCTAssertEqual(layout.blockMap.count, 29)
    }

}
