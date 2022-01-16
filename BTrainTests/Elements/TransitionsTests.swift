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

class TransitionsTests: XCTestCase {

    func testCodable() throws {
        let b1 = Block("b1", type: .station, center: .zero, rotationAngle: 0)
        let b2 = Block("b2", type: .free, center: .zero, rotationAngle: 0)

        let t1 = Transition(id: "1", a: Socket.block(b1.id, socketId: Block.nextSocket), b: Socket.block(b2.id, socketId: Block.previousSocket))
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(t1)

        let decoder = JSONDecoder()
        let t2 = try decoder.decode(Transition.self, from: data)
        
        XCTAssertEqual(t1.id, t2.id)
        XCTAssertEqual(t1.a, t2.a)
        XCTAssertEqual(t1.b, t2.b)
    }
    
    func testReservable() {
        let layout = Layout()
        
        let b1 = Block("b1", type: .station, center: .zero, rotationAngle: 0)
        let b2 = Block("b2", type: .free, center: .zero, rotationAngle: 0)

        let t1 = Transition(id: "1", a: Socket.block(b1.id, socketId: Block.nextSocket), b: Socket.block(b2.id, socketId: Block.previousSocket))
        let t2 = Transition(id: "2", a: Socket.block(b2.id, socketId: Block.nextSocket), b: Socket.block(b1.id, socketId: Block.previousSocket))
        
        let transitions = [t1, t2]
        
        let tr1 = Identifier<Train>(uuid: "t1")
        XCTAssertNoThrow(try Transition.canReserve(transitions: transitions, for: tr1, layout: layout))
        
        t2.reserved = tr1
        XCTAssertNoThrow(try Transition.canReserve(transitions: transitions, for: tr1, layout: layout))
        
        let tr2 = Identifier<Train>(uuid: "t2")
        t2.reserved = tr2
        XCTAssertThrowsError(try Transition.canReserve(transitions: transitions, for: tr1, layout: layout))
    }
    
    func testReverse() {
        let b1 = Block("b1", type: .station, center: .zero, rotationAngle: 0)
        let b2 = Block("b2", type: .free, center: .zero, rotationAngle: 0)

        let t1 = Transition(id: "1", a: Socket.block(b1.id, socketId: Block.nextSocket), b: Socket.block(b2.id, socketId: Block.previousSocket))

        let t11 = t1.reverse

        let tr1 = Identifier<Train>(uuid: "t1")

        t1.reserved = tr1
        XCTAssertEqual(t1.reserved, tr1)
        XCTAssertEqual(t11.reserved, tr1)
        
        let tr2 = Identifier<Train>(uuid: "t2")

        t11.reserved = tr2
        XCTAssertEqual(t1.reserved, tr2)
        XCTAssertEqual(t11.reserved, tr2)
    }
    
    func testSocket() {
        let s1 = Socket(block: Identifier<Block>(uuid: "b1"), turnout: nil, socketId: 0)
        let s2 = Socket(block: Identifier<Block>(uuid: "b1"), turnout: nil, socketId: 1)
        let s3 = Socket(block: Identifier<Block>(uuid: "b1"), turnout: nil, socketId: nil)
        
        XCTAssertFalse(s1.contains(other: s2))
        XCTAssertTrue(s1.contains(other: s3))
        XCTAssertTrue(s2.contains(other: s3))
    }
    
    func testSame() {
        let b1 = Block("b1", type: .station, center: .zero, rotationAngle: 0)
        let b2 = Block("b2", type: .free, center: .zero, rotationAngle: 0)

        let t1 = Transition(id: "1", a: Socket.block(b1.id, socketId: Block.nextSocket), b: Socket.block(b2.id, socketId: Block.previousSocket))
        let t2 = Transition(id: "2", a: Socket.block(b2.id, socketId: Block.nextSocket), b: Socket.block(b1.id, socketId: Block.previousSocket))
        let t1b = Transition(id: "1b", a: Socket.block(b2.id, socketId: Block.previousSocket), b: Socket.block(b1.id, socketId: Block.nextSocket))
        let t1c = Transition(id: "1c", a: Socket.block(b1.id, socketId: Block.nextSocket), b: Socket.block(b2.id))

        XCTAssertEqual(t1, t1)
        XCTAssertNotEqual(t1, t2)
        XCTAssertNotEqual(t2, t1)
        XCTAssertNotEqual(t1, t1b)
        XCTAssertNotEqual(t1b, t1c)

        XCTAssertFalse(t1.same(as: t2))
        XCTAssertTrue(t1.same(as: t1b))
        XCTAssertTrue(t1.same(as: t1c))
    }
    
    func testReserveBehavior() throws {
        let v8 = LayoutFCreator().newLayout()
        
        let t1 = v8.trains[0]
        let t2 = v8.trains[1]
        
        let c1 = TrainController(layout: v8, train: t1)
        let c2 = TrainController(layout: v8, train: t2)

        let r1 = v8.routes[0]
        let r2 = v8.routes[1]

        try v8.prepare(routeID: r1.id, trainID: t1.id)
        try v8.prepare(routeID: r2.id, trainID: t2.id)
        
        try v8.start(routeID: r1.id, trainID: t1.id)
        try v8.start(routeID: r2.id, trainID: t2.id)
        
        try c1.run()
        try c2.run()
        
        // t1 starts but t2 cannot because t1 has reserved all the transitions
        // out of the first block - transitions that are shared with t2's route.
        XCTAssertEqual(t1.speed.kph, LayoutFactory.DefaultSpeed)
        XCTAssertEqual(t2.speed.kph, 0)
        
        // NOTE: stop cannot freeup blocks automatically because
        // the train might be already in transit between two blocks!
        try v8.stopTrain(t1.id)
        // So we manually free up the first block and all the transitions to the next one
        try v8.free(fromBlock: r1.steps[0].blockId, toBlockNotIncluded: r1.steps[1].blockId, direction: .next)
        
        try c1.run()
        try c2.run()
        
        // Now t2 starts because it can reserve the route
        XCTAssertEqual(t1.speed.kph, 0)
        XCTAssertEqual(t2.speed.kph, LayoutFactory.DefaultSpeed)
    }

}
