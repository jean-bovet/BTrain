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

import Foundation

import XCTest

@testable import BTrain

class TrainTests: XCTestCase {
    
    func testCodable() throws {
        let t1 = Train(uuid: "1")
        t1.name = "Rail 2000"
        t1.address = .init(0x4001, .MFX)
        t1.speed = 120
        t1.routeIndex = 1
        t1.position = 7
        t1.blockId = Identifier<Block>(uuid: "111")
        t1.routeId = Identifier<Route>(uuid: "1212")
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(t1)

        let decoder = JSONDecoder()
        let t2 = try decoder.decode(Train.self, from: data)
        
        XCTAssertEqual(t1.id, t2.id)
        XCTAssertEqual(t1.name, t2.name)
        XCTAssertEqual(t1.address, t2.address)
        XCTAssertEqual(t1.speed, t2.speed)
        XCTAssertEqual(t1.routeIndex, t2.routeIndex)
        XCTAssertEqual(t1.position, t2.position)
        XCTAssertEqual(t1.blockId, t2.blockId)
        XCTAssertEqual(t1.routeId, t2.routeId)
    }
}

