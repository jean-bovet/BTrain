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
        let b1 = Block(name: "b1")
        b1.category = .station
        let b2 = Block(name: "b2")

        let t1 = Transition(id: "1", a: Socket.block(b1.id, socketId: Block.nextSocket), b: Socket.block(b2.id, socketId: Block.previousSocket))
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(t1)

        let decoder = JSONDecoder()
        let t2 = try decoder.decode(Transition.self, from: data)
        
        XCTAssertEqual(t1.id, t2.id)
        XCTAssertEqual(t1.a, t2.a)
        XCTAssertEqual(t1.b, t2.b)
    }
    
    func testReverse() {
        let b1 = Block(name: "b1")
        b1.category = .station
        let b2 = Block(name: "b2")

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
        let b1 = Block(name: "b1")
        b1.category = .station
        let b2 = Block(name: "b2")

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
        let v8 = LayoutComplex().newLayout().removeTrains()
        let doc = LayoutDocument(layout: v8)

        let t1 = v8.trains[0]
        t1.wagonsPushedByLocomotive = false
        t1.maxNumberOfLeadingReservedBlocks = 2
        let t2 = v8.trains[1]
        t2.wagonsPushedByLocomotive = false
        t2.maxNumberOfLeadingReservedBlocks = 1

        let r1 = v8.routes[0]
        let r2 = v8.routes[1]
        
        connectToSimulator(doc: doc) { }
        defer {
            disconnectFromSimulator(doc: doc)
        }

        try assert(v8, r1, t1, "{NE1 ≏ ≏ } <B.4{sl}(2,0),l> <A.1{sl}(2,0),l> <A.34{ds2}(3,0),b03> [OL1 ≏ ≏ ] <D.1{sr}(0,1),s> [OL2 ≏ ≏ ] <E.1{sl}(1,0),s> [OL3 ≏ ≏ ] <F.3{sr}(0,1),s> <F.1{sr}(0,2),r> <E.4{sr}(0,2),r> {NE1 ≏ ≏ }")
        try assert(v8, r2, t2, "{NE2 ≏ ≏ } <B.4{sl}(1,0),s> <A.1{sl}(2,0),l> <A.34{ds2}(3,2),s23> <A.2{sr}(2,0),r> [IL1 ≏ ≏ ] <H.1{sl}(1,0),s> <D.2{ds2}(0,1),s01> [IL2 ≏ ≏ ≏ ] <E.3{sl}(0,1),s> <E.2{sl}(1,0),s> [IL3 ≏ ≏ ] <F.4{sr}(0,1),s> [IL4 ≏ ≏ ] <D.4{sl}(1,0),s> <A.2{sr}(1,0),s> [IL1 ≏ ≏ ] <H.1{sl}(1,0),s> <D.2{ds2}(0,1),s01> [IL2 ≏ ≏ ≏ ] <E.3{sl}(0,2),l> <E.1{sl}(2,0),l> [OL3 ≏ ≏ ] <F.3{sr}(0,1),s> <F.1{sr}(0,2),r> <E.4{sr}(0,1),s> {NE2 ≏ ≏ }")

        try v8.prepare(routeID: r1.id, trainID: t1.id, startAtEndOfBlock: true)
        try v8.prepare(routeID: r2.id, trainID: t2.id, startAtEndOfBlock: true)
        
        try assert(v8, r1, t1, "{r16390{NE1 💺16390 ≏ 💺16390 ≏ 🔴🚂16390 }} <B.4{sl}(2,0),l> <A.1{sl}(2,0),l> <A.34{ds2}(3,0),b03> [OL1 ≏ ≏ ] <D.1{sr}(0,1),s> [OL2 ≏ ≏ ] <E.1{sl}(1,0),s> [OL3 ≏ ≏ ] <F.3{sr}(0,1),s> <F.1{sr}(0,2),r> <E.4{sr}(0,2),r> {r16390{NE1 💺16390 ≏ 💺16390 ≏ 🔴🚂16390 }}")
        try assert(v8, r2, t2, "{r16405{NE2 ≏ 💺16405 ≏ 🔴🚂16405 }} <B.4{sl}(1,0),s> <A.1{sl}(2,0),l> <A.34{ds2}(3,2),s23> <A.2{sr}(2,0),r> [IL1 ≏ ≏ ] <H.1{sl}(1,0),s> <D.2{ds2}(0,1),s01> [IL2 ≏ ≏ ≏ ] <E.3{sl}(0,1),s> <E.2{sl}(1,0),s> [IL3 ≏ ≏ ] <F.4{sr}(0,1),s> [IL4 ≏ ≏ ] <D.4{sl}(1,0),s> <A.2{sr}(1,0),s> [IL1 ≏ ≏ ] <H.1{sl}(1,0),s> <D.2{ds2}(0,1),s01> [IL2 ≏ ≏ ≏ ] <E.3{sl}(0,2),l> <E.1{sl}(2,0),l> [OL3 ≏ ≏ ] <F.3{sr}(0,1),s> <F.1{sr}(0,2),r> <E.4{sr}(0,1),s> {r16405{NE2 ≏ 💺16405 ≏ 🔴🚂16405 }}")

        try doc.start(train: t1.id, withRoute: r1.id, destination: nil)
        try doc.start(train: t2.id, withRoute: r2.id, destination: nil)

        doc.layoutController.runControllers(.feedbackTriggered)

        waitForLeadingReservedAndSettled(train: t1)

        // t1 starts but t2 cannot because t1 has reserved all the transitions
        // out of the first block - transitions that are shared with t2's route.
        XCTAssertEqual(t1.speed.requestedKph, LayoutFactory.DefaultLimitedSpeed, accuracy: 1)
        XCTAssertEqual(t2.speed.requestedKph, 0)
        
        try assert(v8, r1, t1, "{r16390{NE1 💺16390 ≏ 💺16390 ≏ 🟢🚂16390 }} <r16390<B.4{sl}(2,0),l>> <r16390<A.1{sl}(2,0),l>> <r16390<A.34{ds2}(3,0),b03>> [r16390[OL1 ≏ ≏ ]] <r16390<D.1{sr}(0,1),s>> [r16390[OL2 ≏ ≏ ]] <E.1{sl}(1,0),s> [OL3 ≏ ≏ ] <F.3{sr}(0,1),s> <F.1{sr}(0,2),r> <E.4{sr}(0,2),r> {r16390{NE1 💺16390 ≏ 💺16390 ≏ 🟢🚂16390 }}")
        try assert(v8, r2, t2, "{r16405{NE2 ≏ 💺16405 ≏ 🔴🚂16405 }} <r16390<B.4{sl}(1,0),s>> <r16390<A.1{sl}(2,0),l>> <r16390<A.34{ds2}(3,2),s23>> <A.2{sr}(2,0),r> [IL1 ≏ ≏ ] <H.1{sl}(1,0),s> <D.2{ds2}(0,1),s01> [IL2 ≏ ≏ ≏ ] <E.3{sl}(0,1),s> <E.2{sl}(1,0),s> [IL3 ≏ ≏ ] <F.4{sr}(0,1),s> [IL4 ≏ ≏ ] <D.4{sl}(1,0),s> <A.2{sr}(1,0),s> [IL1 ≏ ≏ ] <H.1{sl}(1,0),s> <D.2{ds2}(0,1),s01> [IL2 ≏ ≏ ≏ ] <E.3{sl}(0,2),l> <E.1{sl}(2,0),l> [OL3 ≏ ≏ ] <F.3{sr}(0,1),s> <F.1{sr}(0,2),r> <E.4{sr}(0,1),s> {r16405{NE2 ≏ 💺16405 ≏ 🔴🚂16405 }}")

        // NOTE: stop cannot free-up blocks automatically because
        // the train might be already in transit between two blocks!
        doc.layoutController.stop(train: t1)
        
        // So we manually free up the first block and all the transitions to the next one
        try v8.free(fromBlock: r1.steps[0].stepBlockId!, toBlockNotIncluded: r1.steps[1].stepBlockId!, direction: .next)
        doc.layoutController.runControllers(.movedToNextBlock)
        
        waitForLeadingReservedAndSettled(train: t2)

        // Note: train t1 has been stopped so only train t2 can actually start
        try assert(v8, r1, t1, "{NE1 ≏ ≏ } <r16405<B.4{sl}(2,0),l>> <r16405<A.1{sl}(2,0),l>> <r16405<A.34{ds2}(3,0),b03>> [r16390[OL1 ≏ ≏ ]] <r16390<D.1{sr}(0,1),s>> [r16390[OL2 ≏ ≏ ]] <E.1{sl}(1,0),s> [OL3 ≏ ≏ ] <F.3{sr}(0,1),s> <F.1{sr}(0,2),r> <E.4{sr}(0,2),r> {NE1 ≏ ≏ }")
        try assert(v8, r2, t2, "{r16405{NE2 ≏ 💺16405 ≏ 🟢🚂16405 }} <r16405<B.4{sl}(1,0),s>> <r16405<A.1{sl}(2,0),l>> <r16405<A.34{ds2}(3,2),s23>> <r16405<A.2{sr}(2,0),r>> [r16405[IL1 ≏ ≏ ]] <H.1{sl}(1,0),s> <D.2{ds2}(0,1),s01> [IL2 ≏ ≏ ≏ ] <E.3{sl}(0,1),s> <E.2{sl}(1,0),s> [IL3 ≏ ≏ ] <F.4{sr}(0,1),s> [IL4 ≏ ≏ ] <D.4{sl}(1,0),s> <r16405<A.2{sr}(1,0),s>> [r16405[IL1 ≏ ≏ ]] <H.1{sl}(1,0),s> <D.2{ds2}(0,1),s01> [IL2 ≏ ≏ ≏ ] <E.3{sl}(0,2),l> <E.1{sl}(2,0),l> [OL3 ≏ ≏ ] <F.3{sr}(0,1),s> <F.1{sr}(0,2),r> <E.4{sr}(0,1),s> {r16405{NE2 ≏ 💺16405 ≏ 🟢🚂16405 }}")

        // Now t2 starts because it can reserve the route
        XCTAssertEqual(t1.speed.requestedKph, 0)
        XCTAssertEqual(t2.speed.requestedKph, LayoutFactory.DefaultLimitedSpeed)
    }

    private func assert(_ layout: Layout, _ route: Route, _ train: Train, _ expected: String) throws {
        let ascii = LayoutASCIIProducer(layout: layout)
        XCTAssertEqual(try ascii.stringFrom(route: route, trainId: train.id), expected)
    }
}
