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

final class TrainVisitorTests: XCTestCase {
    
    // MARK: Occupation
    
    func testOccupationSingleBlock() {
        let layout = Layout()
        let tv = TrainVisitor(layout: layout)
        
        let block = Block()
        block.length = 100
                
        var position: TrainLocation
        position = .front(blockId: block.id, index: 2, distance: 80)
                
        // [      >
        //  ---->
        //  b   f
        //  <---- (visit)
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: block, trainPosition: position, frontBlock: true, directionOfVisit: .previous, trainForward: true), 80)
        
        // <      ]
        //  ---->
        //  b   f
        //  <---- (visit)
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: block, trainPosition: position, frontBlock: true, directionOfVisit: .next, trainForward: true), 20)
        
        // Note: now test with the train runnings backward. In that case, the back position is used instead of the front
        position = .back(blockId: block.id, index: 2, distance: 20)

        // <      ]
        //  ----<
        //  b   f
        //  -----> (visit)
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: block, trainPosition: position, frontBlock: true, directionOfVisit: .previous, trainForward: false), 20)
        
        // [      >
        //  ----< (train)
        //  b   f
        //  -----> (visit)
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: block, trainPosition: position, frontBlock: true, directionOfVisit: .next, trainForward: false), 80)
    }

    func testOccupationFrontBlockOnly() {
        let layout = Layout()
        let tv = TrainVisitor(layout: layout)
        
        let ba = Block()
        ba.length = 100

        let bb = Block()
        bb.length = 100

        let front = TrainPosition(blockId: ba.id, index: 2, distance: 80)
        let back = TrainPosition(blockId: bb.id, index: 1, distance: 20)
        let position = TrainLocation(front: front, back: back)
                
        //    [      >
        //  ---->
        //  b   f
        //  <---- (visit)
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: ba, trainPosition: position, frontBlock: true, directionOfVisit: .previous, trainForward: true), 80)
        
        //    <      ]
        //  ---->
        //  b   f
        //  -----> (visit)
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: ba, trainPosition: position, frontBlock: true, directionOfVisit: .next, trainForward: true), 20)
    }

    func testOccupationNonFrontBlock() {
        let layout = Layout()
        let tv = TrainVisitor(layout: layout)
        
        let ba = Block()
        ba.length = 100

        let bb = Block()
        bb.length = 100

        let front = TrainPosition(blockId: ba.id, index: 2, distance: 80)
        let back = TrainPosition(blockId: bb.id, index: 1, distance: 20)
        let position = TrainLocation(front: front, back: back)
                        
        // Note: doesn't matter where the train is located, if it is not the front block, the entire length of the block will be used because this method does not
        // take into account the length of the train (remaining).
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: ba, trainPosition: position, frontBlock: false, directionOfVisit: .previous, trainForward: true), 100)
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: ba, trainPosition: position, frontBlock: false, directionOfVisit: .next, trainForward: true), 100)
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: ba, trainPosition: position, frontBlock: false, directionOfVisit: .previous, trainForward: false), 100)
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: ba, trainPosition: position, frontBlock: false, directionOfVisit: .next, trainForward: false), 100)
    }

    // MARK: Visit
    
    func testVisitSingleBlock() throws {        
        let layout = Layout()
        let tv = TrainVisitor(layout: layout)
        
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
        train.locomotive?.directionForward = true
        block.trainInstance = .init(train.id, .next)
        train.position = .front(blockId: block.id, index: 2, distance: 80)
        
        try assert(tv, train: train, remainingTrainLength: -20, blocks: [block])
        
        // [        ]>
        //   >-----
        //   f    b
        train.locomotive?.directionForward = false
        block.trainInstance = .init(train.id, .next)
        train.position = .back(blockId: block.id, index: 2, distance: 80)

        try assert(tv, train: train, remainingTrainLength: -20, blocks: [block])
        
        // [        ]>
        //   <-----
        //   f
        train.locomotive?.directionForward = true
        block.trainInstance = .init(train.id, .previous)
        train.position = .front(blockId: block.id, index: 2, distance: 20)

        try assert(tv, train: train, remainingTrainLength: -20, blocks: [block])

        // [        ]>
        //   -----<
        //   b    f
        train.locomotive?.directionForward = false
        block.trainInstance = .init(train.id, .previous)
        train.position = .back(blockId: block.id, index: 2, distance: 20)

        try assert(tv, train: train, remainingTrainLength: -20, blocks: [block])
    }
    
    /// Test visiting a train that spans two blocks
    func testVisitSpanningTwoBlocks() throws {
        let layout = Layout()
        let tv = TrainVisitor(layout: layout)
        
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

        train.locomotive?.directionForward = true
        ba.trainInstance = .init(train.id, .next)
        bb.trainInstance = .init(train.id, .next)
        train.block = bb

        train.position = .front(blockId: bb.id, index: 0, distance: 20)
        try assert(tv, train: train, remainingTrainLength: -60, blocks: [bb, ba])
        
        train.position = .front(blockId: bb.id, index: 0, distance: 40)
        try assert(tv, train: train, remainingTrainLength: -80, blocks: [bb, ba])

        // ba[  ]>   bb[   ]>
        //     ----------< (train and direction of travel)
        //     b         f
        //     ----------> (direction of visit/occupation filling)
        
        train.locomotive?.directionForward = false
        ba.trainInstance = .init(train.id, .previous)
        bb.trainInstance = .init(train.id, .previous)
        train.block = ba

        train.position = .back(blockId: ba.id, index: 0, distance: 80)
        try assert(tv, train: train, remainingTrainLength: -60, blocks: [ba, bb])
        
        train.position = .back(blockId: ba.id, index: 0, distance: 60)
        try assert(tv, train: train, remainingTrainLength: -80, blocks: [ba, bb])

        train.position = .back(blockId: ba.id, index: 0, distance: 40)
        try assert(tv, train: train, remainingTrainLength: 0, blocks: [ba])

        // ba<[  ]   bb<[   ]
        //      ---------->
        //      b         f
        //      <---------- (direction of visit/occupation filling)

        layout.transitions.elements.removeAll()
        layout.link(from: ba.previous, to: bb.next)

        train.locomotive?.directionForward = true
        ba.trainInstance = .init(train.id, .previous)
        bb.trainInstance = .init(train.id, .previous)
        train.block = bb

        train.position = .front(blockId: bb.id, index: 0, distance: 20)
        try assert(tv, train: train, remainingTrainLength: -20, blocks: [bb])
        
        train.position = .front(blockId: bb.id, index: 0, distance: 40)
        try assert(tv, train: train, remainingTrainLength: 0, blocks: [bb])

        train.position = .front(blockId: bb.id, index: 0, distance: 60)
        try assert(tv, train: train, remainingTrainLength: -80, blocks: [bb, ba])

        // ba<[  ]   bb<[   ]
        //      ----------<
        //      b         f
        //      ----------> (direction of visit/occupation filling)

        train.locomotive?.directionForward = false
        ba.trainInstance = .init(train.id, .next)
        bb.trainInstance = .init(train.id, .next)
        train.block = ba

        train.position = .back(blockId: ba.id, index: 0, distance: 20)
        try assert(tv, train: train, remainingTrainLength: -60, blocks: [ba, bb])

        train.position = .back(blockId: ba.id, index: 0, distance: 40)
        try assert(tv, train: train, remainingTrainLength: -80, blocks: [ba, bb])

        train.position = .back(blockId: ba.id, index: 0, distance: 60)
        try assert(tv, train: train, remainingTrainLength: 0, blocks: [ba])
    }

    /// Test visiting a train that spans three blocks
    func testVisitSpanningThreeBlocks() throws {
        let layout = Layout()
        let tv = TrainVisitor(layout: layout)
        
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

        train.locomotive?.directionForward = true
        ba.trainInstance = .init(train.id, .next)
        bb.trainInstance = .init(train.id, .next)
        bc.trainInstance = .init(train.id, .next)
        train.block = bc

        train.position = .front(blockId: bc.id, index: 1, distance: 20)
        try assert(tv, train: train, remainingTrainLength: -60, blocks: [bc, bb, ba])

        train.position = .front(blockId: bc.id, index: 1, distance: 40)
        try assert(tv, train: train, remainingTrainLength: -80, blocks: [bc, bb, ba])

        train.position = .front(blockId: bc.id, index: 1, distance: 60)
        try assert(tv, train: train, remainingTrainLength: 0, blocks: [bc, bb])

        // ba[  ]>   bb[   ]>  bc[   ]>
        //     --------------------<
        //     b                   f
        //     --------------------> (direction of visit/occupation filling)
        
        train.locomotive?.directionForward = false
        ba.trainInstance = .init(train.id, .previous)
        bb.trainInstance = .init(train.id, .previous)
        bc.trainInstance = .init(train.id, .previous)
        train.block = ba

        train.position = .back(blockId: ba.id, index: 1, distance: 80)
        try assert(tv, train: train, remainingTrainLength: -60, blocks: [ba, bb, bc])
        
        train.position = .back(blockId: ba.id, index: 1, distance: 60)
        try assert(tv, train: train, remainingTrainLength: -80, blocks: [ba, bb, bc])

        train.position = .back(blockId: ba.id, index: 1, distance: 40)
        try assert(tv, train: train, remainingTrainLength: 0, blocks: [ba, bb])

        // ba<[  ]   bb<[   ]  bc<[    ]
        //      ------------------->
        //      b                  f
        //      <------------------- (direction of visit/occupation filling)

        layout.transitions.elements.removeAll()
        layout.link(from: ba.previous, to: bb.next)
        layout.link(from: bb.previous, to: bc.next)

        train.locomotive?.directionForward = true
        ba.trainInstance = .init(train.id, .previous)
        bb.trainInstance = .init(train.id, .previous)
        bc.trainInstance = .init(train.id, .previous)
        train.block = bc

        train.position = .front(blockId: bc.id, index: 1, distance: 80)
        try assert(tv, train: train, remainingTrainLength: -60, blocks: [bc, bb, ba])
        
        train.position = .front(blockId: bc.id, index: 1, distance: 40)
        try assert(tv, train: train, remainingTrainLength: 0, blocks: [bc, bb])

        // ba<[  ]   bb<[   ]   bc<[   ]
        //      --------------------<
        //      b                   f
        //      --------------------> (direction of visit/occupation filling)

        train.locomotive?.directionForward = false
        ba.trainInstance = .init(train.id, .next)
        bb.trainInstance = .init(train.id, .next)
        bc.trainInstance = .init(train.id, .next)
        train.block = ba

        train.position = .back(blockId: ba.id, index: 1, distance: 80)
        try assert(tv, train: train, remainingTrainLength: -20, blocks: [ba, bb])
        
        train.position = .back(blockId: ba.id, index: 1, distance: 60)
        try assert(tv, train: train, remainingTrainLength: 0, blocks: [ba, bb])
        
        // ba<[  ]   bb<[   ]  bc>[    ]
        //      ------------------->
        //      b                  f
        //      <------------------- (direction of visit/occupation filling)

        layout.transitions.elements.removeAll()
        layout.link(from: ba.previous, to: bb.next)
        layout.link(from: bb.previous, to: bc.previous)

        train.locomotive?.directionForward = true
        ba.trainInstance = .init(train.id, .previous)
        bb.trainInstance = .init(train.id, .previous)
        bc.trainInstance = .init(train.id, .next)
        train.block = bc

        train.position = .front(blockId: bc.id, index: 1, distance: 80)
        try assert(tv, train: train, remainingTrainLength: -20, blocks: [bc, bb])
        
        train.position = .front(blockId: bc.id, index: 1, distance: 40)
        try assert(tv, train: train, remainingTrainLength: -80, blocks: [bc, bb, ba])
    }
    
    private func assert(_ tv: TrainVisitor, train: Train, remainingTrainLength: Double, blocks: [Block]) throws {
        var blocks = [Block]()

        let remainingTrainLength = try tv.visit(train: train) { _ in
            
        } turnoutCallback: { turnoutInfo in

        } blockCallback: { block, blockAttributes in
            blocks.append(block)
        }

        XCTAssertEqual(remainingTrainLength, remainingTrainLength, "Remaining train length mismatch")
        XCTAssertEqual(blocks.toBlockNames, blocks.toBlockNames, "Visited blocks mismatch")
    }
}

extension Array where Element == Block {
    
    var toBlockNames: [String] {
        self.map { $0.name }
    }
    
}
