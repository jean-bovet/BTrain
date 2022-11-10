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

class LocomotiveTests: XCTestCase {
    
    func testCodable() throws {
        let t1 = Locomotive(uuid: "1")
        t1.name = "Rail 2000"
        t1.address = 0x4001
        t1.speed.requestedKph = 100
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(t1)

        let decoder = JSONDecoder()
        let t2 = try decoder.decode(Locomotive.self, from: data)
        
        XCTAssertEqual(t1.id, t2.id)
        XCTAssertEqual(t1.name, t2.name)
        XCTAssertEqual(t1.address, t2.address)
        XCTAssertEqual(t1.speed.decoderType, t2.speed.decoderType)
        XCTAssertEqual(t1.speed.requestedKph, 100)
        XCTAssertEqual(t2.speed.requestedKph, 0) // When decoding a speed, it always is initialized back to 0 for security reason
    }
    
}
