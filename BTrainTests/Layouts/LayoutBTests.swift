// Copyright 2021 Jean Bovet
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

class LayoutBTests: RootLayoutTests {

    override var layoutID: Identifier<Layout>? {
        return LayoutBCreator.id
    }

    func testTransitionsAndTurnoutsReservation() throws {
        let train1 = layout.trains[0]
        let train2 = layout.trains[1]
        
        let b1 = layout.block(at: 0)
        let b2 = layout.block(at: 1)
        let b3 = layout.block(at: 2)
        let b4 = layout.block(at: 3)
        
        try layout.setTrain(train1.id, toBlock: b1.id, direction: .next)
        try layout.setTrain(train2.id, toBlock: b3.id, direction: .next)
        
        XCTAssertNoThrow(try layout.reserve(train: train1.id, fromBlock: b1.id, toBlock: b2.id, direction: .next))
        
        // Ensure that train 2 cannot reserve its block because they are overlapping with
        // the turnout which itself is already reserved for train 1
        XCTAssertThrowsError(try layout.reserve(train: train2.id, fromBlock: b3.id, toBlock: b4.id, direction: .next))
        
        // Now let's free the blocks reserved by train 1 (but keep it in its block) and try again to reserve for train 2, it should work this time
        try layout.free(trainID: train1.id)
        XCTAssertNotNil(b1.reserved)
        XCTAssertNotNil(train1.blockId)

        XCTAssertNoThrow(try layout.reserve(train: train2.id, fromBlock: b3.id, toBlock: b4.id, direction: .next))
        
        // Now let's remove train 1 from the layout
        try layout.free(trainID: train1.id, removeFromLayout: true)
        XCTAssertNil(b1.reserved)
        XCTAssertNil(train1.blockId)
    }

    func testAddFeedback() throws {
        let f1 = layout.newFeedback()
        let f2 = layout.feedback(for: f1.id)
        XCTAssertEqual(f1, f2)
        
        layout.remove(feedbackID: f1.id)
        XCTAssertNil(layout.feedback(for: f1.id))
    }
    
    func testAddTurnout() throws {
        let t1 = layout.newTurnout(name: "t1", type: .doubleSlip)
        let t2 = layout.turnout(for: t1.id)
        XCTAssertEqual(t1, t2)
        
        layout.remove(turnoutID: t1.id)
        XCTAssertNil(layout.turnout(for: t1.id))
    }
    
    func testAddBlock() throws {
        let b1 = layout.newBlock(name: "b1", type: .free)
        let b2 = layout.block(for: b1.id)
        XCTAssertTrue(b1 === b2)
        
        layout.remove(blockID: b1.id)
        XCTAssertNil(layout.block(for: b1.id))
    }
}
