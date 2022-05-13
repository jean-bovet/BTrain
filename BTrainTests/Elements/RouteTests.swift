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

class RouteTests: XCTestCase {

    func testCodable() throws {
        let r1 = Route(uuid: "1")
        r1.name = "r1"
        r1.steps = [.block(RouteStepBlock(Identifier<Block>(uuid: "1"), .next)),
                    .block(RouteStepBlock(Identifier<Block>(uuid: "2"), .previous)),
                    .block(RouteStepBlock(Identifier<Block>(uuid: "3"), .next))]
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(r1)

        let decoder = JSONDecoder()
        let r2 = try decoder.decode(Route.self, from: data)
        
        XCTAssertEqual(r1.id, r2.id)
        XCTAssertEqual(r1.name, r2.name)
        XCTAssertEqual(r1.steps, r2.steps)
    }
    
    func testStep() {
        let s1 = RouteStepBlock(Identifier<Block>(uuid: "1"), .next)
        let s2 = RouteStepBlock(Identifier<Block>(uuid: "1"), .previous)
        let s3 = RouteStepBlock(Identifier<Block>(uuid: "2"), .next)
        var s4 = RouteStepBlock(Identifier<Block>(uuid: "2"), .next)
        s4.id = s3.id
        XCTAssertEqual(s1, s1)
        XCTAssertNotEqual(s1, s2)
        XCTAssertNotEqual(s2, s3)
        XCTAssertEqual(s3, s4)
    }
}
