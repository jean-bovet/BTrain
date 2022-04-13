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

class ShortestPathComplexTests: XCTestCase {

    func testPath1() throws {
        let layout = LayoutComplex().newLayout()
        let ne1 = layout.block(named: "NE1")
        let hsl_p1 = layout.block(named: "HLS_P1")
        let path = try DijkstraAlgorithm.shortestPath(graph: layout,
                                                      from: ne1.elementDirectionNext,
                                                      to: hsl_p1.elementDirectionNext)!
        XCTAssertEqual(path.toStrings, ["0:NE1:1", "2:B.4:0", "2:A.1:0", "3:A.34:2", "2:A.2:0", "0:IL1:1", "1:H.1:0", "0:D.2:3", "1:S:0", "2:F.4:0", "1:IL3:0", "0:E.2:1", "1:E.3:0", "1:IL2:0", "1:D.2:0", "0:H.1:2", "0:HL1:1", "0:H.2:2", "0:HLS_P1:1"])
    }

}
