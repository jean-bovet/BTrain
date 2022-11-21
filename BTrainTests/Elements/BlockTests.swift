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
        let b1 = Block(name: "empty")
        b1.category = .station
        b1.center = .init(x: 10, y: 20)
        b1.rotationAngle = .pi
        b1.reservation = Reservation("t1", .previous)
        b1.trainInstance = .init(b1.reservation!.trainId, .previous)
        XCTAssertEqual(b1.trainInstance?.direction, .previous)

        b1.trainInstance = .init(b1.reservation!.trainId, .next)
        XCTAssertEqual(b1.trainInstance?.direction, .next)
    }

    func testBlockSockets() {
        let b1 = Block(name: "empty")
        b1.category = .station
        b1.center = .init(x: 10, y: 20)
        b1.rotationAngle = .pi

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
        let b1 = Block(name: "empty")
        b1.category = .station
        b1.center = .init(x: 10, y: 20)
        b1.rotationAngle = .pi
        b1.reservation = Reservation("t1", .previous)
        b1.trainInstance = .init(b1.reservation!.trainId, .previous)

        let feedbacks = [Identifier<Feedback>(uuid: "1"), Identifier<Feedback>(uuid: "2")]
        b1.assign(feedbacks)

        XCTAssertFalse(b1.trainInstance?.direction == .next)

        let encoder = JSONEncoder()
        let data = try encoder.encode(b1)

        let decoder = JSONDecoder()
        let b2 = try decoder.decode(Block.self, from: data)

        XCTAssertEqual(b1.id, b2.id)
        XCTAssertEqual(b1.category, b2.category)
        XCTAssertEqual(b1.center, b2.center)
        XCTAssertEqual(b1.rotationAngle, b2.rotationAngle)
        XCTAssertEqual(b1.reservation?.trainId, b2.reservation?.trainId)
        XCTAssertEqual(b1.reservation?.direction, b2.reservation?.direction)
        XCTAssertEqual(b1.trainInstance, b2.trainInstance)
        XCTAssertEqual(b1.trainInstance?.direction, b2.trainInstance?.direction)
        XCTAssertEqual(b1.feedbacks, b2.feedbacks)
    }

    func testFeedbacksForEmptyBlock() {
        let block = Block(name: "empty")

        XCTAssertNil(block.entryFeedback(for: .next))
        XCTAssertNil(block.entryFeedback(for: .previous))

        XCTAssertNil(block.brakeFeedback(for: .next))
        XCTAssertNil(block.brakeFeedback(for: .previous))

        XCTAssertNil(block.stopFeedback(for: .next))
        XCTAssertNil(block.stopFeedback(for: .previous))
    }

    let f1 = Identifier<Feedback>(uuid: "f1")
    let f2 = Identifier<Feedback>(uuid: "f2")
    let f3 = Identifier<Feedback>(uuid: "f3")
    let f4 = Identifier<Feedback>(uuid: "f4")

    func testFeedbacksForBlockWith1Feedback() {
        let block = Block(name: "empty")
        block.assign([f1])

        XCTAssertEqual(block.entryFeedback(for: .next), f1)
        XCTAssertEqual(block.entryFeedback(for: .previous), f1)

        XCTAssertEqual(block.brakeFeedback(for: .next), f1)
        XCTAssertEqual(block.brakeFeedback(for: .previous), f1)

        XCTAssertEqual(block.stopFeedback(for: .next), f1)
        XCTAssertEqual(block.stopFeedback(for: .previous), f1)
    }

    func testFeedbacksForBlockWith2Feedbacks() {
        let block = Block(name: "empty")
        block.assign([f1, f2])

        XCTAssertEqual(block.entryFeedback(for: .next), f1)
        XCTAssertEqual(block.entryFeedback(for: .previous), f2)

        XCTAssertEqual(block.brakeFeedback(for: .next), f1)
        XCTAssertEqual(block.brakeFeedback(for: .previous), f2)

        XCTAssertEqual(block.stopFeedback(for: .next), f2)
        XCTAssertEqual(block.stopFeedback(for: .previous), f1)
    }

    func testFeedbacksForBlockWith3Feedbacks() {
        let block = Block(name: "empty")
        block.assign([f1, f2, f3])

        XCTAssertEqual(block.entryFeedback(for: .next), f1)
        XCTAssertEqual(block.entryFeedback(for: .previous), f3)

        XCTAssertEqual(block.brakeFeedback(for: .next), f2)
        XCTAssertEqual(block.brakeFeedback(for: .previous), f2)

        XCTAssertEqual(block.stopFeedback(for: .next), f3)
        XCTAssertEqual(block.stopFeedback(for: .previous), f1)
    }

    func testFeedbacksForBlockWith4Feedbacks() {
        let block = Block(name: "empty")
        block.assign([f1, f2, f3, f4])

        XCTAssertEqual(block.entryFeedback(for: .next), f1)
        XCTAssertEqual(block.entryFeedback(for: .previous), f4)

        XCTAssertEqual(block.brakeFeedback(for: .next), f2)
        XCTAssertEqual(block.brakeFeedback(for: .previous), f3)

        XCTAssertEqual(block.stopFeedback(for: .next), f4)
        XCTAssertEqual(block.stopFeedback(for: .previous), f1)

        block.entryFeedbackNext = f2
        block.brakeFeedbackNext = f3
        block.stopFeedbackNext = f4

        block.entryFeedbackPrevious = f3
        block.brakeFeedbackPrevious = f2
        block.stopFeedbackPrevious = f1

        XCTAssertEqual(block.entryFeedback(for: .next), f2)
        XCTAssertEqual(block.entryFeedback(for: .previous), f3)

        XCTAssertEqual(block.brakeFeedback(for: .next), f3)
        XCTAssertEqual(block.brakeFeedback(for: .previous), f2)

        XCTAssertEqual(block.stopFeedback(for: .next), f4)
        XCTAssertEqual(block.stopFeedback(for: .previous), f1)
    }

    func testDistanceRemainingInBlock() {
        let block = Block(name: "b1")
        block.length = 100
        block.assign([f1, f2, f3])
        block.feedbacks[0].distance = 10
        block.feedbacks[1].distance = 50
        block.feedbacks[2].distance = 90

        let t = Train(id: .init(uuid: "t1"), name: "SBB")
        t.locomotive = Locomotive(name: "loc1")
        t.locomotive?.directionForward = true
        block.trainInstance = .init(t.id, .next)

        // Block:    [ f1 f2 f3 ]
        // Position:  0  1  2  3
        // Direction: ------>
        // TODO: position
//        t.position = 0
//        XCTAssertEqual(block.distanceLeftInBlock(train: t), 90)
//        t.position = 1
//        XCTAssertEqual(block.distanceLeftInBlock(train: t), 50)
//        t.position = 2
//        XCTAssertEqual(block.distanceLeftInBlock(train: t), 10)
//        t.position = 3
//        XCTAssertEqual(block.distanceLeftInBlock(train: t), 0)

        block.trainInstance = .init(t.id, .previous)

        // Block:    [ f1 f2 f3 ]
        // Position:  0  1  2  3
        // Direction:     <-----
        // TODO: position
//        t.position = 3
//        XCTAssertEqual(block.distanceLeftInBlock(train: t), 90)
//        t.position = 2
//        XCTAssertEqual(block.distanceLeftInBlock(train: t), 50)
//        t.position = 1
//        XCTAssertEqual(block.distanceLeftInBlock(train: t), 10)
//        t.position = 0
//        XCTAssertEqual(block.distanceLeftInBlock(train: t), 0)
    }
    
    func testDistanceRemainingInBlockTravelingBackwards() {
        let block = Block(name: "b1")
        block.length = 100
        block.assign([f1, f2, f3])
        block.feedbacks[0].distance = 10
        block.feedbacks[1].distance = 50
        block.feedbacks[2].distance = 90

        let t = Train(id: .init(uuid: "t1"), name: "SBB")
        t.locomotive = Locomotive(name: "loc1")
        t.locomotive?.directionForward = false
        block.trainInstance = .init(t.id, .next)

        // Block:    [ f1 f2 f3 ] >>>
        // Position:  0  1  2  3
        // Direction: >------
        // TODO: position
//        t.position = 0
//        XCTAssertEqual(block.distanceLeftInBlock(train: t), 90)
//        t.position = 1
//        XCTAssertEqual(block.distanceLeftInBlock(train: t), 50)
//        t.position = 2
//        XCTAssertEqual(block.distanceLeftInBlock(train: t), 10)
//        t.position = 3
//        XCTAssertEqual(block.distanceLeftInBlock(train: t), 0)

        block.trainInstance = .init(t.id, .previous)

        // Block:    [ f1 f2 f3 ]
        // Position:  0  1  2  3
        // Direction:     ----->
        // TODO: position
//        t.position = 3
//        XCTAssertEqual(block.distanceLeftInBlock(train: t), 90)
//        t.position = 2
//        XCTAssertEqual(block.distanceLeftInBlock(train: t), 50)
//        t.position = 1
//        XCTAssertEqual(block.distanceLeftInBlock(train: t), 10)
//        t.position = 0
//        XCTAssertEqual(block.distanceLeftInBlock(train: t), 0)
    }

}
