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
    
    func testReserveDirectionNext() throws {
        let layout = LayoutBCreator().newLayout()

        let b1 = layout.blocks[0]
        let b2 = layout.blocks[1]
        let b3 = layout.blocks[2]
        let b4 = layout.blocks[3]

        b1.length = 100
        b1.feedbacks[0].distance = 25
        b1.feedbacks[1].distance = b1.length! - 25

        b2.length = 100
        b2.feedbacks[0].distance = 25
        b2.feedbacks[1].distance = b2.length! - 25
        
        b3.length = 80
        b3.feedbacks[0].distance = 25
        b3.feedbacks[1].distance = b3.length! - 25

        b4.length = 40
        b4.feedbacks[0].distance = 5
        b4.feedbacks[1].distance = b4.length! - 5

        layout.turnouts[0].state = .straight23

        let t1 = layout.trains[0]
        t1.blockId = b1.id
        t1.wagonsDirection = .previous
        t1.position = 2
        b1.train = .init(t1.id, .next)
        
        t1.length = 100+40+100
        try layout.reserveBlocksForTrainLength(train: t1)
        assert(b1, t1, [0:.wagon, 1:.wagon, 2:.locomotive])
        assert(b4, t1, [0:.wagon, 1:.wagon, 2:.wagon])
        assert(b3, t1, [0:.wagon, 1:.wagon, 2:.wagon])
        assert(b2, t1, [1:.wagon, 2:.wagon])

        t1.length = 100+40+60
        try layout.reserveBlocksForTrainLength(train: t1)
        assert(b1, t1, [0:.wagon, 1:.wagon, 2:.locomotive])
        assert(b4, t1, [0:.wagon, 1:.wagon, 2:.wagon])
        assert(b3, t1, [0:.wagon, 1:.wagon, 2:.wagon])
        assert(b2, t1, [2:.wagon])

        t1.length = 80
        try layout.reserveBlocksForTrainLength(train: t1)
        assert(b1, t1, [0:.wagon, 1:.wagon, 2:.locomotive])
        assert(b4, t1, [2:.wagon])
        assert(b3, nil, nil)
        assert(b2, nil, nil)

        t1.length = 2000
        XCTAssertThrowsError(try layout.reserveBlocksForTrainLength(train: t1))
    }

    func testReserveDirectionPrevious() throws {
        let layout = LayoutBCreator().newLayout()

        let b1 = layout.blocks[0]
        let b2 = layout.blocks[1]
        let b3 = layout.blocks[2]
        let b4 = layout.blocks[3]
        
        b1.length = 100
        b1.feedbacks[0].distance = 25
        b1.feedbacks[1].distance = b1.length! - 25

        b2.length = 100
        b2.feedbacks[0].distance = 25
        b2.feedbacks[1].distance = b2.length! - 25
        
        b3.length = 80
        b3.feedbacks[0].distance = 25
        b3.feedbacks[1].distance = b3.length! - 25

        b4.length = 40
        b4.feedbacks[0].distance = 5
        b4.feedbacks[1].distance = b4.length! - 5

        layout.turnouts[0].state = .straight01

        let t1 = layout.trains[0]
        t1.blockId = b4.id
        t1.wagonsDirection = .next
        t1.position = 0
        b4.train = .init(t1.id, .previous)
        
        t1.length = 40+100+100+20
        try layout.reserveBlocksForTrainLength(train: t1)
        assert(b4, t1, [0:.locomotive, 1:.wagon, 2:.wagon])
        assert(b1, t1, [0:.wagon, 1:.wagon, 2:.wagon])
        assert(b2, t1, [0:.wagon, 1:.wagon, 2:.wagon])
        assert(b3, t1, [0:.wagon])

        t1.length = 40+100+100
        try layout.reserveBlocksForTrainLength(train: t1)
        assert(b4, t1, [0:.locomotive, 1:.wagon, 2:.wagon])
        assert(b1, t1, [0:.wagon, 1:.wagon, 2:.wagon])
        assert(b2, t1, [0:.wagon, 1:.wagon, 2:.wagon])
        assert(b3, t1, [0:.wagon])

        t1.length = 40
        try layout.reserveBlocksForTrainLength(train: t1)
        assert(b4, t1, [0:.locomotive, 1:.wagon, 2:.wagon])
        assert(b1, t1, [0:.wagon])
        assert(b2, nil, nil)
        assert(b3, nil, nil)

        t1.length = 2000
        XCTAssertThrowsError(try layout.reserveBlocksForTrainLength(train: t1))
    }

    func assert(_ block: Block, _ train: Train?, _ parts: [Int:TrainInstance.TrainPart]?) {
        XCTAssertEqual(block.reserved?.trainId, train?.id)
        XCTAssertEqual(block.train?.parts, parts)

    }
}
