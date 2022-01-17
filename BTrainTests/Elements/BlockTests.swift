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

extension Reservation {
    init(_ uuid: String, _ direction: Direction) {
        self.init(trainId: Identifier<Train>(uuid: uuid), direction: direction)
    }
}

class BlockTests: XCTestCase {
    
    func testBlockDirection() {
        let b1 = Block("1", type: .station, center: .init(x: 10, y: 20), rotationAngle: .pi)
        b1.reserved = Reservation("t1", .previous)
        b1.train = .init(b1.reserved!.trainId, .previous)
        XCTAssertEqual(b1.train?.direction, .previous)
        
        b1.train = .init(b1.reserved!.trainId, .next)
        XCTAssertEqual(b1.train?.direction, .next)
    }
    
    func testBlockSockets() {
        let b1 = Block("1", type: .station, center: .init(x: 10, y: 20), rotationAngle: .pi)
        
        XCTAssertNil(b1.previous.turnout)
        XCTAssertEqual(b1.previous.block, b1.id)
        XCTAssertEqual(b1.previous.socketId, Block.previousSocket)
        
        XCTAssertNil(b1.next.turnout)
        XCTAssertEqual(b1.next.block, b1.id)
        XCTAssertEqual(b1.next.socketId, Block.nextSocket)

        XCTAssertNil(b1.any.turnout)
        XCTAssertEqual(b1.any.block, b1.id)
        XCTAssertNil(b1.any.socketId)
    }
    
    func testCodable() throws {
        let b1 = Block("1", type: .station, center: .init(x: 10, y: 20), rotationAngle: .pi)
        b1.reserved = Reservation("t1", .previous)
        b1.train = .init(b1.reserved!.trainId, .previous)
        
        let feedbacks = [Identifier<Feedback>(uuid: "1"), Identifier<Feedback>(uuid: "2")]
        b1.assign(feedbacks)
        
        XCTAssertFalse(b1.train?.direction == .next)

        let encoder = JSONEncoder()
        let data = try encoder.encode(b1)

        let decoder = JSONDecoder()
        let b2 = try decoder.decode(Block.self, from: data)

        XCTAssertEqual(b1.id, b2.id)
        XCTAssertEqual(b1.category, b2.category)
        XCTAssertEqual(b1.center, b2.center)
        XCTAssertEqual(b1.rotationAngle, b2.rotationAngle)
        XCTAssertEqual(b1.reserved?.trainId, b2.reserved?.trainId)
        XCTAssertEqual(b1.reserved?.direction, b2.reserved?.direction)
        XCTAssertEqual(b1.train, b2.train)
        XCTAssertEqual(b1.train?.direction, b2.train?.direction)
        XCTAssertEqual(b1.feedbacks, b2.feedbacks)
    }

}
