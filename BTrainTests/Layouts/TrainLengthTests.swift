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

// Using "Layout B"
//   ┌─────────┐                              ┌─────────┐
//┌──│ Block 2 │◀────┐         ┌─────────────▶│ Block 4 │──┐
//│  └─────────┘     │         │              └─────────┘  │
//│                  │         │                           │
//│                  │                                     │
//│                  └─────Turnout1 ◀───┐                  │
//│                                     │                  │
//│                            ▲        │                  │
//│  ┌─────────┐               │        │     ┌─────────┐  │
//└─▶│ Block 3 │───────────────┘        └─────│ Block 1 │◀─┘
//   └─────────┘                              └─────────┘
class TrainLengthTests: XCTestCase {

    func testReserveVariousTrainLengths() throws {
        let layout = LayoutBCreator().newLayout()
        let b1 = layout.blocks[0]
        let b2 = layout.blocks[1]
        let b3 = layout.blocks[2]
        let b4 = layout.blocks[3]
        
        b1.length = 100
        b2.length = 100
        b3.length = 80
        b4.length = 40
        
        layout.turnouts[0].state = .straight23

        let t1 = layout.trains[0]
        t1.blockId = b1.id
        
        t1.length = 100+40+100
        try layout.reserveBlocksForTrainLength(train: t1)
        XCTAssertEqual(b1.reserved?.trainId, t1.id)
        XCTAssertEqual(b4.reserved?.trainId, t1.id)
        XCTAssertEqual(b3.reserved?.trainId, t1.id)
        XCTAssertEqual(b2.reserved?.trainId, t1.id)

        t1.length = 100+40+60
        
        try layout.reserveBlocksForTrainLength(train: t1)
        XCTAssertEqual(b1.reserved?.trainId, t1.id)
        XCTAssertEqual(b4.reserved?.trainId, t1.id)
        XCTAssertEqual(b3.reserved?.trainId, t1.id)
        XCTAssertNil(b2.reserved)

        t1.length = 80
        try layout.reserveBlocksForTrainLength(train: t1)
        XCTAssertEqual(b1.reserved?.trainId, t1.id)
        XCTAssertNil(b2.reserved)
        XCTAssertNil(b3.reserved)
        XCTAssertNil(b4.reserved)
                                
        t1.length = 2000
        XCTAssertThrowsError(try layout.reserveBlocksForTrainLength(train: t1))
    }

}
