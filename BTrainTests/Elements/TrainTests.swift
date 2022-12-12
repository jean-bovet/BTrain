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
        let layout = Layout()
        layout.blocks.add(Block(id: Identifier<Block>(uuid: "111")))
        
        let t1 = Train(uuid: "1")
        t1.name = "Rail 2000"
        t1.routeStepIndex = 1
        t1.positions.head = .init(blockId: Identifier<Block>(uuid: "1"), index: 1, distance: 10)
        t1.positions.tail = .init(blockId: Identifier<Block>(uuid: "2"), index: 2, distance: 20)
        t1.block = layout.blocks[0]
        t1.routeId = Identifier<Route>(uuid: "1212")

        let encoder = JSONEncoder()
        let data = try encoder.encode(t1)

        let decoder = JSONDecoder()
        let t2 = try decoder.decode(Train.self, from: data)
        t2.restore(layout: layout)

        XCTAssertEqual(t1.id, t2.id)
        XCTAssertEqual(t1.name, t2.name)
        XCTAssertEqual(t1.routeStepIndex, t2.routeStepIndex)
        XCTAssertEqual(t1.positions, t2.positions)
        XCTAssertEqual(t1.block, t2.block)
        XCTAssertEqual(t1.routeId, t2.routeId)
    }
    
    func testBlockProperty() {
        let train = Train()
        var blocks = [Block?]()
        let cancellable = train.$block.sink { block in
            blocks.append(block)
        }
        
        XCTAssertNotNil(cancellable)
        
        let a1 = Block(name: "a1")
        let a2 = Block(name: "a2")
        train.block = a1
        train.block = nil
        train.block = a2
        
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks, [a1, nil, a2])
    }
}
