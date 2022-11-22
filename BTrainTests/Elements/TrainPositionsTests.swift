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

final class TrainPositionsTests: XCTestCase {

    typealias TLF = TrainLocation.FeedbackPosition
    typealias TP = TrainPosition

    // MARK: - Train Forward -

    // TODO: also test when a train spans more than one block (occupied.blocks.count > 1)
    func testMoveForwardSameBlock() {
        var location = TrainLocation()
        
        // Block (􁉆): [ p0 f0 p1 f1 p2 f2 p3 ]
        // Train (􀼯􀼮):           ??
        assertLocation(location, back: nil, front: nil)

        // Block (􁉆): [ p0 |f0| p1 f1 p2 f2 p3 ]
        // Train (􀼯􀼮):        bf
        location = assertFeedback(forward: true, location: location, feedback: TLF(blockIndex: 0, index: 0), back: TrainPosition(blockIndex: 0, index: 1), front: TrainPosition(blockIndex: 0, index: 1))

        // Block (􁉆): [ p0 f0 p1 |f1| p2 f2 p3 ]
        // Train (􀼯􀼮):              bf
        location = assertFeedback(forward: true, location: location, feedback: TLF(blockIndex: 0, index: 1), back: TrainPosition(blockIndex: 0, index: 2), front: TrainPosition(blockIndex: 0, index: 2))

        // Block (􁉆): [ p0 |f0| p1 f1 p2 f2 p3 ]
        // Train (􀼯􀼮):        b     f
        location = assertFeedback(forward: true, location: location, feedback: TLF(blockIndex: 0, index: 0), back: TrainPosition(blockIndex: 0, index: 1), front: TrainPosition(blockIndex: 0, index: 2))

        // Block (􁉆): [ p0 f0 p1 f1 p2 |f2| p3 ]
        // Train (􀼯􀼮):      b             f
        location = assertFeedback(forward: true, location: location, feedback: TLF(blockIndex: 0, index: 2), back: TrainPosition(blockIndex: 0, index: 1), front: TrainPosition(blockIndex: 0, index: 3))
    }

    func testMoveForwardSameBlockPrevious() {
        var location = TrainLocation()
        
        // Block (􁉈): [ p3 f2 p2 f1 p1 f0 p0 ]
        // Train (􀼯􀼮):           ??
        assertLocation(location, back: nil, front: nil)

        // Block (􁉈): [ p3 |f2| p2 f1 p1 f0 p0 ]
        // Train (􀼯􀼮):        bf
        location = assertFeedback(forward: true, location: location, feedback: TLF(blockIndex: 0, index: 2, direction: .previous), back: TP(blockIndex: 0, index: 2, direction: .previous), front: TP(blockIndex: 0, index: 2, direction: .previous))

        // Block (􁉈): [ p3 f2 p2 |f1| p1 f0 p0 ]
        // Train (􀼯􀼮):              bf
        location = assertFeedback(forward: true, location: location, feedback: TLF(blockIndex: 0, index: 1, direction: .previous), back: TP(blockIndex: 0, index: 1, direction: .previous), front: TP(blockIndex: 0, index: 1, direction: .previous))
        
        // Block (􁉈): [ p3 |f2| p2 f1 p1 f0 p0 ]
        // Train (􀼯􀼮):        b     f
        location = assertFeedback(forward: true, location: location, feedback: TLF(blockIndex: 0, index: 2, direction: .previous), back: TP(blockIndex: 0, index: 2, direction: .previous), front: TP(blockIndex: 0, index: 1, direction: .previous))

        // Block (􁉈): [ p3 f2 p2 f1 p1 |f0| p0 ]
        // Train (􀼯􀼮):      b             f
        location = assertFeedback(forward: true, location: location, feedback: TLF(blockIndex: 0, index: 0, direction: .previous), back: TP(blockIndex: 0, index: 2, direction: .previous), front: TP(blockIndex: 0, index: 0, direction: .previous))
    }

    func testMoveForwardNextBlock() {
        var location = TrainLocation()
        assertLocation(location, back: nil, front: nil)

        location = assertFeedback(forward: true, location: location, feedback: TLF(blockIndex: 0, index: 1), back: TrainPosition(blockIndex: 0, index: 2), front: TrainPosition(blockIndex: 0, index: 2))
        location = assertFeedback(forward: true, location: location, feedback: TLF(blockIndex: 0, index: 2), back: TrainPosition(blockIndex: 0, index: 3), front: TrainPosition(blockIndex: 0, index: 3))
        location = assertFeedback(forward: true, location: location, feedback: TLF(blockIndex: 0, index: 1), back: TrainPosition(blockIndex: 0, index: 2), front: TrainPosition(blockIndex: 0, index: 3))
        location = assertFeedback(forward: true, location: location, feedback: TLF(blockIndex: 0, index: 3), back: TrainPosition(blockIndex: 0, index: 2), front: TrainPosition(blockIndex: 0, index: 4))
        
        // Next block feedback is triggered
        location = assertFeedback(forward: true, location: location, feedback: TLF(blockIndex: 1, index: 0), back: TrainPosition(blockIndex: 0, index: 2), front: TrainPosition(blockIndex: 1, index: 1))
        location = assertFeedback(forward: true, location: location, feedback: TLF(blockIndex: 1, index: 0), back: TrainPosition(blockIndex: 1, index: 1), front: TrainPosition(blockIndex: 1, index: 1))
    }
    
    func testMoveForwardNextBlockPreviousDirection() {
        var location = TrainLocation()
        assertLocation(location, back: nil, front: nil)

        location = assertFeedback(forward: true, location: location, feedback: TLF(blockIndex: 0, index: 1), back: TrainPosition(blockIndex: 0, index: 2), front: TrainPosition(blockIndex: 0, index: 2))
        location = assertFeedback(forward: true, location: location, feedback: TLF(blockIndex: 0, index: 2), back: TrainPosition(blockIndex: 0, index: 3), front: TrainPosition(blockIndex: 0, index: 3))
        location = assertFeedback(forward: true, location: location, feedback: TLF(blockIndex: 0, index: 1), back: TrainPosition(blockIndex: 0, index: 2), front: TrainPosition(blockIndex: 0, index: 3))
        location = assertFeedback(forward: true, location: location, feedback: TLF(blockIndex: 0, index: 3), back: TrainPosition(blockIndex: 0, index: 2), front: TrainPosition(blockIndex: 0, index: 4))
        
        // Next block feedback is triggered
        location = assertFeedback(forward: true, location: location, feedback: TLF(blockIndex: 1, index: 3, direction: .previous), back: TrainPosition(blockIndex: 0, index: 2), front: TrainPosition(blockIndex: 1, index: 3, direction: .previous))
        location = assertFeedback(forward: true, location: location, feedback: TLF(blockIndex: 1, index: 3, direction: .previous), back: TrainPosition(blockIndex: 1, index: 3, direction: .previous), front: TrainPosition(blockIndex: 1, index: 3, direction: .previous))
    }

    // MARK: - Train Backward -
    
    func testMoveBackwardSameBlock() {
        var location = TrainLocation()
        
        // Block (􁉆): [ p0 f0 p1 f1 p2 f2 p3 ]
        // Train (􀼮􀼯):           ??
        assertLocation(location, back: nil, front: nil)

        // Block (􁉆): [ p0 |f0| p1 f1 p2 f2 p3 ]
        // Train (􀼮􀼯):        fb
        location = assertFeedback(forward: false, location: location, feedback: TLF(blockIndex: 0, index: 0), back: TrainPosition(blockIndex: 0, index: 1), front: TrainPosition(blockIndex: 0, index: 1))

        // Block (􁉆): [ p0 f0 p1 |f1| p2 f2 p3 ]
        // Train (􀼮􀼯):              fb
        location = assertFeedback(forward: false, location: location, feedback: TLF(blockIndex: 0, index: 1), back: TrainPosition(blockIndex: 0, index: 2), front: TrainPosition(blockIndex: 0, index: 2))

        // Block (􁉆): [ p0 |f0| p1 f1 p2 f2 p3 ]
        // Train (􀼮􀼯):        f     b
        location = assertFeedback(forward: false, location: location, feedback: TLF(blockIndex: 0, index: 0), back: TrainPosition(blockIndex: 0, index: 2), front: TrainPosition(blockIndex: 0, index: 1))

        // Block (􁉆): [ p0 f0 p1 f1 p2 |f2| p3 ]
        // Train (􀼮􀼯):      f             b
        location = assertFeedback(forward: false, location: location, feedback: TLF(blockIndex: 0, index: 2), back: TrainPosition(blockIndex: 0, index: 3), front: TrainPosition(blockIndex: 0, index: 1))
    }

    func testMoveBackwardSameBlockPrevious() {
        var location = TrainLocation()
        
        // Block (􁉈): [ p3 f2 p2 f1 p1 f0 p0 ]
        // Train (􀼮􀼯):           ??
        assertLocation(location, back: nil, front: nil)

        // Block (􁉈): [ p3 |f2| p2 f1 p1 f0 p0 ]
        // Train (􀼮􀼯):        fb
        location = assertFeedback(forward: false, location: location, feedback: TLF(blockIndex: 0, index: 2, direction: .previous), back: TP(blockIndex: 0, index: 2, direction: .previous), front: TP(blockIndex: 0, index: 2, direction: .previous))

        // Block (􁉈): [ p3 f2 p2 |f1| p1 f0 p0 ]
        // Train (􀼮􀼯):              fb
        location = assertFeedback(forward: false, location: location, feedback: TLF(blockIndex: 0, index: 1, direction: .previous), back: TP(blockIndex: 0, index: 1, direction: .previous), front: TP(blockIndex: 0, index: 1, direction: .previous))
        
        // Block (􁉈): [ p3 |f2| p2 f1 p1 f0 p0 ]
        // Train (􀼮􀼯):        f     b
        location = assertFeedback(forward: false, location: location, feedback: TLF(blockIndex: 0, index: 2, direction: .previous), back: TP(blockIndex: 0, index: 1, direction: .previous), front: TP(blockIndex: 0, index: 2, direction: .previous))

        // Block (􁉈): [ p3 f2 p2 f1 p1 |f0| p0 ]
        // Train (􀼮􀼯):      f             b
        location = assertFeedback(forward: false, location: location, feedback: TLF(blockIndex: 0, index: 0, direction: .previous), back: TP(blockIndex: 0, index: 0, direction: .previous), front: TP(blockIndex: 0, index: 2, direction: .previous))
    }

    func testMoveBackwardNextBlock() {
        var location = TrainLocation()
        assertLocation(location, back: nil, front: nil)

        location = assertFeedback(forward: false, location: location, feedback: TLF(blockIndex: 0, index: 1), back: TrainPosition(blockIndex: 0, index: 2), front: TrainPosition(blockIndex: 0, index: 2))
        location = assertFeedback(forward: false, location: location, feedback: TLF(blockIndex: 0, index: 2), back: TrainPosition(blockIndex: 0, index: 3), front: TrainPosition(blockIndex: 0, index: 3))
        location = assertFeedback(forward: false, location: location, feedback: TLF(blockIndex: 0, index: 1), back: TrainPosition(blockIndex: 0, index: 3), front: TrainPosition(blockIndex: 0, index: 2))
        location = assertFeedback(forward: false, location: location, feedback: TLF(blockIndex: 0, index: 3), back: TrainPosition(blockIndex: 0, index: 4), front: TrainPosition(blockIndex: 0, index: 2))
        
        // Next block feedback is triggered
        location = assertFeedback(forward: false, location: location, feedback: TLF(blockIndex: 1, index: 0), back: TrainPosition(blockIndex: 1, index: 1), front: TrainPosition(blockIndex: 0, index: 2))
        location = assertFeedback(forward: false, location: location, feedback: TLF(blockIndex: 1, index: 0), back: TrainPosition(blockIndex: 1, index: 1), front: TrainPosition(blockIndex: 1, index: 1))
    }
    
    func testMoveBackwardNextBlockPreviousDirection() {
        var location = TrainLocation()
        assertLocation(location, back: nil, front: nil)

        location = assertFeedback(forward: false, location: location, feedback: TLF(blockIndex: 0, index: 1), back: TrainPosition(blockIndex: 0, index: 2), front: TrainPosition(blockIndex: 0, index: 2))
        location = assertFeedback(forward: false, location: location, feedback: TLF(blockIndex: 0, index: 2), back: TrainPosition(blockIndex: 0, index: 3), front: TrainPosition(blockIndex: 0, index: 3))
        location = assertFeedback(forward: false, location: location, feedback: TLF(blockIndex: 0, index: 1), back: TrainPosition(blockIndex: 0, index: 3), front: TrainPosition(blockIndex: 0, index: 2))
        location = assertFeedback(forward: false, location: location, feedback: TLF(blockIndex: 0, index: 3), back: TrainPosition(blockIndex: 0, index: 4), front: TrainPosition(blockIndex: 0, index: 2))
        
        // Next block feedback is triggered
        location = assertFeedback(forward: false, location: location, feedback: TLF(blockIndex: 1, index: 3, direction: .previous), back: TrainPosition(blockIndex: 1, index: 3, direction: .previous), front: TrainPosition(blockIndex: 0, index: 2))
        location = assertFeedback(forward: false, location: location, feedback: TLF(blockIndex: 1, index: 3, direction: .previous), back: TrainPosition(blockIndex: 1, index: 3, direction: .previous), front: TrainPosition(blockIndex: 1, index: 3, direction: .previous))
    }

    // MARK: - Helper -
    
    private func assertFeedback(forward: Bool, location currentLocation: TrainLocation, feedback feedbackIndex: TLF, back: TrainPosition?, front: TrainPosition?) -> TrainLocation {
        let newLocation = TrainLocation.newLocationWith(trainMovesForward: forward, currentLocation: currentLocation, feedbackIndex: feedbackIndex)
        
        assertLocation(newLocation, back: back, front: front)

        return newLocation
    }
    
    private func assertLocation(_ location: TrainLocation, back: TrainPosition?, front: TrainPosition?) {
        XCTAssertEqual(location.back, back)
        XCTAssertEqual(location.front, front)
    }
}
