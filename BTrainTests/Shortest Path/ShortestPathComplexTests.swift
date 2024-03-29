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

import XCTest

// These unit tests are using the LayoutComplex layout to find a few shortest path
// that are more complex to compute and requires using the same node again but
// from another direction of travel.
class ShortestPathComplexTests: XCTestCase {
    func testPath1() throws {
        let layout = LayoutComplex().newLayout()
        try layout.assertShortPath(("NE1", .next), ("HLS_P1", .next), ["0:NE1:1", "2:B.4:0", "2:A.1:0", "3:A.34:2", "2:A.2:0", "0:IL1:1", "1:H.1:0", "0:D.2:1", "0:IL2:1", "0:E.3:1", "1:E.2:0", "0:IL3:1", "0:F.4:2", "0:S:1", "3:D.2:0", "0:H.1:2", "0:HL1:1", "0:H.2:2", "0:HLS_P1:1"])
    }

    func testPath2() throws {
        let layout = LayoutComplex().newLayout()
        try layout.assertShortPath(("NE4", .next), ("LCF1", .next), ["0:NE4:1", "1:B.2:2", "2:B.3:0", "1:A.1:0", "3:A.34:2", "2:A.2:0", "0:IL1:1", "1:H.1:0", "0:D.2:1", "0:IL2:1", "0:E.3:1", "1:E.2:0", "0:IL3:1", "0:F.4:2", "0:S:1", "3:D.2:0", "0:H.1:1", "1:IL1:0", "0:A.2:2", "2:A.34:3", "0:A.1:1", "0:B.3:2", "2:B.2:1", "1:NE4:0", "1:C.1:0", "0:M.1:1", "0:M1:1", "0:Z.1:1", "0:M2U:1", "1:Z.2:0", "0:Z.4:1", "0:LCF1:1"])
    }

    func testPath3() throws {
        let layout = LayoutComplex().newLayout()
        try layout.assertShortPath(("HS1", .next), ("NE1", .next), ["0:HS1:1", "2:H.4:0", "2:D.4:0", "1:A.2:0", "0:IL1:1", "1:H.1:0", "0:D.2:1", "0:IL2:1", "0:E.3:2", "2:E.1:0", "0:OL3:1", "0:F.3:1", "0:F.1:2", "0:E.4:2", "0:NE1:1"])
    }

    func testPath4() throws {
        let layout = LayoutComplex().newLayout()
        try layout.assertShortPath(("NE1", .next), ("NE2", .next), ["0:NE1:1", "2:B.4:0", "2:A.1:0", "3:A.34:2", "2:A.2:0", "0:IL1:1", "1:H.1:0", "0:D.2:1", "0:IL2:1", "0:E.3:2", "2:E.1:0", "0:OL3:1", "0:F.3:1", "0:F.1:2", "0:E.4:1", "0:NE2:1"])
    }

    func testPath5() throws {
        let layout = LayoutComplex().newLayout()
        try layout.assertShortPath(("NE1", .next), ("NE1", .next), ["0:NE1:1", "2:B.4:0", "2:A.1:0", "3:A.34:2", "2:A.2:0", "0:IL1:1", "1:H.1:0", "0:D.2:1", "0:IL2:1", "0:E.3:2", "2:E.1:0", "0:OL3:1", "0:F.3:1", "0:F.1:2", "0:E.4:2", "0:NE1:1"])
    }

    func testPerformancePath1() throws {
        let layout = LayoutComplex().newLayout()
        let ne1 = layout.block(named: "NE1")
        let hsl_p1 = layout.block(named: "HLS_P1")
        let constraints = PathFinder.Constraints(layout: layout, train: layout.trains[0], reservedBlockBehavior: .avoidReserved, stopAtFirstBlock: false, relaxed: false)
        measure {
            _ = try? ShortestPathFinder.shortestPath(graph: layout,
                                                     from: ne1.elementDirectionNext,
                                                     to: hsl_p1.elementDirectionNext, constraints: constraints,
                                                     verbose: false)
        }
    }
}
