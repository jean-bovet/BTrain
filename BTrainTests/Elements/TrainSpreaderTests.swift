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

final class TrainSpreaderTests: XCTestCase {
    // MARK: Occupation

    func testOccupationSingleBlock() throws {
        let layout = Layout()
        let tv = TrainSpreader(layout: layout)

        let block = Block()
        block.length = 100

        var position: TrainPositions
        position = .head(blockId: block.id, index: 2, distance: 80)

        // [      >
        //  ---->
        //  b   f
        //  <---- (visit)
        XCTAssertEqual(try tv.occupiedLengthOfTrainInBlock(block: block, position: position.head!, frontBlock: true, directionOfSpread: .previous, trainForward: true), 80)

        // <      ]
        //  ---->
        //  b   f
        //  <---- (visit)
        XCTAssertEqual(try tv.occupiedLengthOfTrainInBlock(block: block, position: position.head!, frontBlock: true, directionOfSpread: .next, trainForward: true), 20)

        // Note: now test with the train runnings backward. In that case, the back position is used instead of the front
        position = .tail(blockId: block.id, index: 2, distance: 20)

        // <      ]
        //  ----<
        //  b   f
        //  -----> (visit)
        XCTAssertEqual(try tv.occupiedLengthOfTrainInBlock(block: block, position: position.tail!, frontBlock: true, directionOfSpread: .previous, trainForward: false), 20)

        // [      >
        //  ----< (train)
        //  b   f
        //  -----> (visit)
        XCTAssertEqual(try tv.occupiedLengthOfTrainInBlock(block: block, position: position.tail!, frontBlock: true, directionOfSpread: .next, trainForward: false), 80)
    }

    func testOccupationFrontBlockOnly() throws {
        let layout = Layout()
        let tv = TrainSpreader(layout: layout)

        let ba = Block()
        ba.length = 100

        let bb = Block()
        bb.length = 100

        let head = TrainPosition(blockId: ba.id, index: 2, distance: 80)
        let tail = TrainPosition(blockId: bb.id, index: 1, distance: 20)
        let position = TrainPositions(head: head, tail: tail)

        //    [      >
        //  ---->
        //  b   f
        //  <---- (visit)
        XCTAssertEqual(try tv.occupiedLengthOfTrainInBlock(block: ba, position: position.head!, frontBlock: true, directionOfSpread: .previous, trainForward: true), 80)

        //    <      ]
        //  ---->
        //  b   f
        //  -----> (visit)
        XCTAssertEqual(try tv.occupiedLengthOfTrainInBlock(block: ba, position: position.head!, frontBlock: true, directionOfSpread: .next, trainForward: true), 20)
    }

    func testOccupationNonFrontBlock() throws {
        let layout = Layout()
        let tv = TrainSpreader(layout: layout)

        let ba = Block()
        ba.length = 100

        let bb = Block()
        bb.length = 100

        let front = TrainPosition(blockId: ba.id, index: 2, distance: 80)
        let back = TrainPosition(blockId: bb.id, index: 1, distance: 20)
        let position = TrainPositions(head: front, tail: back)

        // Note: doesn't matter where the train is located, if it is not the front block, the entire length of the block will be used because this method does not
        // take into account the length of the train (remaining).
        XCTAssertEqual(try tv.occupiedLengthOfTrainInBlock(block: ba, position: position.head!, frontBlock: false, directionOfSpread: .previous, trainForward: true), 100)
        XCTAssertEqual(try tv.occupiedLengthOfTrainInBlock(block: ba, position: position.head!, frontBlock: false, directionOfSpread: .next, trainForward: true), 100)
        XCTAssertEqual(try tv.occupiedLengthOfTrainInBlock(block: ba, position: position.head!, frontBlock: false, directionOfSpread: .previous, trainForward: false), 100)
        XCTAssertEqual(try tv.occupiedLengthOfTrainInBlock(block: ba, position: position.head!, frontBlock: false, directionOfSpread: .next, trainForward: false), 100)
    }

    func testSpread() throws {
        let layout = Layout()
        let tv = TrainSpreader(layout: layout)

        let b0 = Block(name: "b0")
        b0.length = 100
        layout.blocks.add(b0)

        let b1 = Block(name: "b1")
        b1.length = 100
        b1.feedbacks.append(.init(id: "f1", feedbackId: .init(uuid: "f1"), distance: 50))
        layout.blocks.add(b1)

        let b2 = Block(name: "b2")
        b2.length = 100
        b2.feedbacks.append(.init(id: "f2.1", feedbackId: .init(uuid: "f2.1"), distance: 20))
        b2.feedbacks.append(.init(id: "f2.2", feedbackId: .init(uuid: "f2.2"), distance: 80))
        layout.blocks.add(b2)

        let b3 = Block(name: "b3")
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

        try assert(tv: tv, block: b0, distance: 50, direction: .next, lengthOfTrain: 50, expected: [[(0, true, true, 100)]])

        try assert(tv: tv, block: b1, distance: 0, direction: .next, lengthOfTrain: 10, expected: [[(0, true, true, 10)]])
        try assert(tv: tv, block: b1, distance: 0, direction: .next, lengthOfTrain: 50, expected: [[(0, true, true, 50)]])
        try assert(tv: tv, block: b1, distance: 0, direction: .next, lengthOfTrain: 51, expected: [[(0, true, false, 50), (1, false, true, 51)]])
        try assert(tv: tv, block: b1, distance: 20, direction: .next, lengthOfTrain: 50, expected: [[(0, true, false, 50), (1, false, true, 70)]])
        try assert(tv: tv, block: b1, distance: 20, direction: .next, lengthOfTrain: 30, expected: [[(0, true, true, 50)]])
        try assert(tv: tv, block: b1, distance: 20, direction: .next, lengthOfTrain: 20, expected: [[(0, true, true, 40)]])
        try assert(tv: tv, block: b1, distance: 60, direction: .next, lengthOfTrain: 50, expected: [[(1, true, false, 100)], [(0, false, true, 10)]])
        try assert(tv: tv, block: b1, distance: 60, direction: .next, lengthOfTrain: 40, expected: [[(1, true, true, 100)]])
        try assert(tv: tv, block: b1, distance: 60, direction: .next, lengthOfTrain: 20, expected: [[(1, true, true, 80)]])
        try assert(tv: tv, block: b1, distance: 100, direction: .next, lengthOfTrain: 20, expected: [[(1, true, false, 100)], [(0, false, true, 20)]])
        
        try assert(tv: tv, block: b2, distance: 50, direction: .previous, lengthOfTrain: 50, expected: [[(1, true, false, 20), (0, false, true, 0)]])
        try assert(tv: tv, block: b2, distance: 100, direction: .previous, lengthOfTrain: 20, expected: [[(2, true, true, 80)]])
        try assert(tv: tv, block: b2, distance: 20, direction: .previous, lengthOfTrain: 20, expected: [[(0, true, true, 0)]])
        
        try assert(tv: tv, block: b2, distance: 60, direction: .next, lengthOfTrain: 60, expected: [[(1, true, false, 80), (2, false, false, 100)], [(2, false, true, 90)]])
        try assert(tv: tv, block: b3, distance: 60, direction: .previous, lengthOfTrain: 80, success: false, expected: [[(1, true, false, 30), (0, false, false, 0)]])
    }

    struct SpreadResults {
        var transitions = [Transition]()
        var turnouts = [ElementVisitor.TurnoutInfo]()
        var blocks = [TrainSpreader.SpreadBlockInfo]()
        var success = true
    }
    
    private func spread(tv: TrainSpreader, block: Block, distance: Double, direction: Direction, lengthOfTrain: Double) throws -> SpreadResults {
        var results = SpreadResults()
        results.success = try tv.spread(blockId: block.id, distance: distance, direction: direction, lengthOfTrain: lengthOfTrain, transitionCallback: { transition in
            results.transitions.append(transition)
        }, turnoutCallback: { turnoutInfo in
            results.turnouts.append(turnoutInfo)
        }, blockCallback: { spreadBlockInfo in
            results.blocks.append(spreadBlockInfo)
        })
        return results
    }
    
    private func assert(tv: TrainSpreader, block: Block, distance: Double, direction: Direction, lengthOfTrain: Double, success: Bool = true, expected: [[(Int, Bool, Bool, Double)]]) throws {
        let results = try spread(tv: tv, block: block, distance: distance, direction: direction, lengthOfTrain: lengthOfTrain)
        XCTAssertEqual(results.success, success)

        for (index, block) in results.blocks.enumerated() {
            let parts = block.parts
            XCTAssertEqual(parts.count, expected[index].count, "Mismatch in the number of parts")
            
            for (pindex, part) in parts.enumerated() {
                XCTAssertEqual(part.partIndex, expected[index][pindex].0)
                XCTAssertEqual(part.firstPart, expected[index][pindex].1)
                XCTAssertEqual(part.lastPart, expected[index][pindex].2)
                XCTAssertEqual(part.distance, expected[index][pindex].3)
            }
        }
    }
    
    // MARK: Spreading

    func testSpreadSingleBlock() throws {
        let layout = Layout()
        let tv = TrainSpreader(layout: layout)

        let block = Block()
        block.length = 100
        layout.blocks.add(block)

        let loc = Locomotive()
        let train = Train()
        train.wagonsLength = 60
        train.locomotive = loc
        train.block = block

        // [        ]>
        //   ----->
        //   b    f
        train.locomotive!.directionForward = true
        block.trainInstance = .init(train.id, .next)
        train.positions = .head(blockId: block.id, index: 2, distance: 80)

        try assert(tv, train: train, remainingTrainLength: -20, blocks: [block])

        // [        ]>
        //   >-----
        //   f    b
        train.locomotive!.directionForward = false
        block.trainInstance = .init(train.id, .next)
        train.positions = .tail(blockId: block.id, index: 2, distance: 80)

        try assert(tv, train: train, remainingTrainLength: -20, blocks: [block])

        // [        ]>
        //   <-----
        //   f
        train.locomotive!.directionForward = true
        block.trainInstance = .init(train.id, .previous)
        train.positions = .head(blockId: block.id, index: 2, distance: 20)

        try assert(tv, train: train, remainingTrainLength: -20, blocks: [block])

        // [        ]>
        //   -----<
        //   b    f
        train.locomotive!.directionForward = false
        block.trainInstance = .init(train.id, .previous)
        train.positions = .tail(blockId: block.id, index: 2, distance: 20)

        try assert(tv, train: train, remainingTrainLength: -20, blocks: [block])
    }

    /// Test spreading a train that spans two blocks
    func testSpreadSpanningTwoBlocks() throws {
        let layout = Layout()
        let tv = TrainSpreader(layout: layout)

        let ba = Block(name: "A")
        ba.length = 100
        layout.blocks.add(ba)

        let bb = Block(name: "B")
        bb.length = 100
        layout.blocks.add(bb)

        layout.link(from: ba.next, to: bb.previous)

        let loc = Locomotive()
        let train = Train()
        train.wagonsLength = 60
        train.locomotive = loc

        // ba[  ]>   bb[   ]>
        //     ---------->
        //     b         f
        //     <---------- (direction of visit/occupation filling)

        train.locomotive!.directionForward = true
        ba.trainInstance = .init(train.id, .next)
        bb.trainInstance = .init(train.id, .next)
        train.block = bb

        train.positions = .head(blockId: bb.id, index: 0, distance: 20)
        try assert(tv, train: train, remainingTrainLength: -60, blocks: [bb, ba])

        train.positions = .head(blockId: bb.id, index: 0, distance: 40)
        try assert(tv, train: train, remainingTrainLength: -80, blocks: [bb, ba])

        // ba[  ]>   bb[   ]>
        //     ----------< (train and direction of travel)
        //     b         f
        //     ----------> (direction of visit/occupation filling)

        train.locomotive!.directionForward = false
        ba.trainInstance = .init(train.id, .previous)
        bb.trainInstance = .init(train.id, .previous)
        train.block = ba

        train.positions = .tail(blockId: ba.id, index: 0, distance: 80)
        try assert(tv, train: train, remainingTrainLength: -60, blocks: [ba, bb])

        train.positions = .tail(blockId: ba.id, index: 0, distance: 60)
        try assert(tv, train: train, remainingTrainLength: -80, blocks: [ba, bb])

        train.positions = .tail(blockId: ba.id, index: 0, distance: 40)
        try assert(tv, train: train, remainingTrainLength: 0, blocks: [ba])

        // ba<[  ]   bb<[   ]
        //      ---------->
        //      b         f
        //      <---------- (direction of visit/occupation filling)

        layout.transitions.elements.removeAll()
        layout.link(from: ba.previous, to: bb.next)

        train.locomotive!.directionForward = true
        ba.trainInstance = .init(train.id, .previous)
        bb.trainInstance = .init(train.id, .previous)
        train.block = bb

        train.positions = .head(blockId: bb.id, index: 0, distance: 20)
        try assert(tv, train: train, remainingTrainLength: -20, blocks: [bb])

        train.positions = .head(blockId: bb.id, index: 0, distance: 40)
        try assert(tv, train: train, remainingTrainLength: 0, blocks: [bb])

        train.positions = .head(blockId: bb.id, index: 0, distance: 60)
        try assert(tv, train: train, remainingTrainLength: -80, blocks: [bb, ba])

        // ba<[  ]   bb<[   ]
        //      ----------<
        //      b         f
        //      ----------> (direction of visit/occupation filling)

        train.locomotive!.directionForward = false
        ba.trainInstance = .init(train.id, .next)
        bb.trainInstance = .init(train.id, .next)
        train.block = ba

        train.positions = .tail(blockId: ba.id, index: 0, distance: 20)
        try assert(tv, train: train, remainingTrainLength: -60, blocks: [ba, bb])

        train.positions = .tail(blockId: ba.id, index: 0, distance: 40)
        try assert(tv, train: train, remainingTrainLength: -80, blocks: [ba, bb])

        train.positions = .tail(blockId: ba.id, index: 0, distance: 60)
        try assert(tv, train: train, remainingTrainLength: 0, blocks: [ba])
    }

    /// Test spreading a train that spans three blocks
    func testSpreadSpanningThreeBlocks() throws {
        let layout = Layout()
        let tv = TrainSpreader(layout: layout)

        let ba = Block(name: "A")
        ba.length = 100
        layout.blocks.add(ba)

        let bb = Block(name: "B")
        bb.length = 100
        layout.blocks.add(bb)

        let bc = Block(name: "C")
        bc.length = 100
        layout.blocks.add(bc)

        let loc = Locomotive()
        let train = Train()
        train.wagonsLength = 160
        train.locomotive = loc

        layout.link(from: ba.next, to: bb.previous)
        layout.link(from: bb.next, to: bc.previous)

        // ba[  ]>   bb[   ]>  bc[   ]>
        //     ------------------->
        //     b                  f
        //     <------------------- (direction of visit/occupation filling)

        train.locomotive!.directionForward = true
        ba.trainInstance = .init(train.id, .next)
        bb.trainInstance = .init(train.id, .next)
        bc.trainInstance = .init(train.id, .next)
        train.block = bc

        train.positions = .head(blockId: bc.id, index: 1, distance: 20)
        try assert(tv, train: train, remainingTrainLength: -60, blocks: [bc, bb, ba])

        train.positions = .head(blockId: bc.id, index: 1, distance: 40)
        try assert(tv, train: train, remainingTrainLength: -80, blocks: [bc, bb, ba])

        train.positions = .head(blockId: bc.id, index: 1, distance: 60)
        try assert(tv, train: train, remainingTrainLength: 0, blocks: [bc, bb])

        // ba[  ]>   bb[   ]>  bc[   ]>
        //     --------------------<
        //     b                   f
        //     --------------------> (direction of visit/occupation filling)

        train.locomotive!.directionForward = false
        ba.trainInstance = .init(train.id, .previous)
        bb.trainInstance = .init(train.id, .previous)
        bc.trainInstance = .init(train.id, .previous)
        train.block = ba

        train.positions = .tail(blockId: ba.id, index: 1, distance: 80)
        try assert(tv, train: train, remainingTrainLength: -60, blocks: [ba, bb, bc])

        train.positions = .tail(blockId: ba.id, index: 1, distance: 60)
        try assert(tv, train: train, remainingTrainLength: -80, blocks: [ba, bb, bc])

        train.positions = .tail(blockId: ba.id, index: 1, distance: 40)
        try assert(tv, train: train, remainingTrainLength: 0, blocks: [ba, bb])

        // ba<[  ]   bb<[   ]  bc<[    ]
        //      ------------------->
        //      b                  f
        //      <------------------- (direction of visit/occupation filling)

        layout.transitions.elements.removeAll()
        layout.link(from: ba.previous, to: bb.next)
        layout.link(from: bb.previous, to: bc.next)

        train.locomotive!.directionForward = true
        ba.trainInstance = .init(train.id, .previous)
        bb.trainInstance = .init(train.id, .previous)
        bc.trainInstance = .init(train.id, .previous)
        train.block = bc

        train.positions = .head(blockId: bc.id, index: 1, distance: 80)
        try assert(tv, train: train, remainingTrainLength: -60, blocks: [bc, bb, ba])

        train.positions = .head(blockId: bc.id, index: 1, distance: 40)
        try assert(tv, train: train, remainingTrainLength: 0, blocks: [bc, bb])

        // ba<[  ]   bb<[   ]   bc<[   ]
        //      --------------------<
        //      b                   f
        //      --------------------> (direction of visit/occupation filling)

        train.locomotive!.directionForward = false
        ba.trainInstance = .init(train.id, .next)
        bb.trainInstance = .init(train.id, .next)
        bc.trainInstance = .init(train.id, .next)
        train.block = ba

        train.positions = .tail(blockId: ba.id, index: 1, distance: 80)
        try assert(tv, train: train, remainingTrainLength: -20, blocks: [ba, bb])

        train.positions = .tail(blockId: ba.id, index: 1, distance: 60)
        try assert(tv, train: train, remainingTrainLength: 0, blocks: [ba, bb])

        // ba<[  ]   bb<[   ]  bc>[    ]
        //      ------------------->
        //      b                  f
        //      <------------------- (direction of visit/occupation filling)

        layout.transitions.elements.removeAll()
        layout.link(from: ba.previous, to: bb.next)
        layout.link(from: bb.previous, to: bc.previous)

        train.locomotive!.directionForward = true
        ba.trainInstance = .init(train.id, .previous)
        bb.trainInstance = .init(train.id, .previous)
        bc.trainInstance = .init(train.id, .next)
        train.block = bc

        train.positions = .head(blockId: bc.id, index: 1, distance: 80)
        try assert(tv, train: train, remainingTrainLength: -20, blocks: [bc, bb])

        train.positions = .head(blockId: bc.id, index: 1, distance: 40)
        try assert(tv, train: train, remainingTrainLength: -80, blocks: [bc, bb, ba])
    }

    private func assert(_ tv: TrainSpreader, train: Train, remainingTrainLength _: Double, blocks _: [Block]) throws {
        var blocks = [Block]()

        let remainingTrainLength = try tv.spread(train: train) { _ in

        } turnoutCallback: { _ in

        } blockCallback: { block, _ in
            blocks.append(block)
        }

        XCTAssertEqual(remainingTrainLength, remainingTrainLength, "Remaining train length mismatch")
        XCTAssertEqual(blocks.toBlockNames, blocks.toBlockNames, "Visited blocks mismatch")
    }
}

extension Array where Element == Block {
    var toBlockNames: [String] {
        self.map(\.name)
    }
}
