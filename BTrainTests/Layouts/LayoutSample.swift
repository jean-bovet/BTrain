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

// b0[ ]> b1[ f1 ]> b2[ f2.1 f2.2 ]> <t23> b3<[ f3.2 f3.1 ]
struct LayoutSample {
    let layout: Layout
    
    let b0: Block
    let b1: Block
    let b2: Block
    let b3: Block

    let train: Train
    let loc: Locomotive
    
    internal init() {
        layout = Layout()

        b0 = Block(name: "b0")
        b0.length = 100
        layout.blocks.add(b0)

        b1 = Block(name: "b1")
        b1.length = 100
        b1.feedbacks.append(.init(id: "f1", feedbackId: .init(uuid: "f1"), distance: 50))
        layout.blocks.add(b1)

        b2 = Block(name: "b2")
        b2.length = 100
        b2.feedbacks.append(.init(id: "f2.1", feedbackId: .init(uuid: "f2.1"), distance: 20))
        b2.feedbacks.append(.init(id: "f2.2", feedbackId: .init(uuid: "f2.2"), distance: 80))
        layout.blocks.add(b2)

        b3 = Block(name: "b3")
        b3.length = 100
        b3.feedbacks.append(.init(id: "f3.1", feedbackId: .init(uuid: "f3.1"), distance: 30))
        b3.feedbacks.append(.init(id: "f3.2", feedbackId: .init(uuid: "f3.2"), distance: 70))
        layout.blocks.add(b3)

        let t23 = Turnout(name: "t23")
        t23.length = 10
        layout.turnouts.add(t23)
        
        layout.link(from: b0.next, to: b1.previous)
        layout.link(from: b1.next, to: b2.previous)
        layout.link(from: b2.next, to: t23.socket0)
        layout.link(from: t23.socket1, to: b3.next)
        
        loc = Locomotive()
        loc.length = 20
        train = Train()
        train.locomotive = loc
    }
    
    /// Reserve the necessary elements for the train at the specified positions and direction in the block
    /// - Parameters:
    ///   - block: the block in which the positions is defined (head or tail depending on the direction of travel and detection)
    ///   - positions: the positions
    func reserve(block: Block, positions: TrainPositions) throws {
        train.positions = positions
        try layout.occupyBlocksWith(train: train)
    }
    
    func assert(_ ti: TrainInstance?, _ direction: Direction, expectedParts: [Int:TrainInstance.TrainPart]) {
        XCTAssertEqual(ti?.trainId, train.id)
        XCTAssertEqual(ti?.direction, direction)
        XCTAssertEqual(ti?.parts, expectedParts, "Mismatching parts")
    }
    
}
