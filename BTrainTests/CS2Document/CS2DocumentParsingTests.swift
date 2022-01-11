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

class CS2DocumentParsingTests: XCTestCase {

    func testParseLocomotive() throws {
        guard let url = Bundle(for: type(of: self )).url(forResource: "Locomotives", withExtension: "cs2") else {
            XCTFail("Unable to find the Locomotives.cs2 file")
            return
        }
        let parser = LocomotivesDocumentParser(text: try String(contentsOf: url))
        guard let locs = parser.parse() else {
            XCTFail("Unable to parse the locomotives")
            return
        }
        
        XCTAssertEqual(locs.count, 11)
        
        assert(loc: locs[0], uid: 0x4006, name: "460 106-8 SBB", address: 0x6, type: "mfx")
        assert(loc: locs[2], uid: 0x2e, name: "BLS", address: 0x2e, type: "mm_prg")
        
        assert(loc: locs[0].commandLocomotive, uid: 0x4006, name: "460 106-8 SBB", address: 0x6, type: .MFX)
        assert(loc: locs[2].commandLocomotive, uid: 0x2e, name: "BLS", address: 0x2e, type: .MM)
    }

    func assert(loc: Locomotive, uid: UInt32, name: String, address: UInt32, type: String) {
        XCTAssertEqual(loc.uid, uid)
        XCTAssertEqual(loc.name, name)
        XCTAssertEqual(loc.address, address)
        XCTAssertEqual(loc.type, type)
    }
    
    func assert(loc: CommandLocomotive, uid: UInt32, name: String, address: UInt32, type: DecoderType) {
        XCTAssertEqual(loc.uid, uid)
        XCTAssertEqual(loc.name, name)
        XCTAssertEqual(loc.address, address)
        XCTAssertEqual(loc.decoderType, type)
    }
}
