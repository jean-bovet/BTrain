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
                
        let front = TrainPosition(blockId: block.id, index: 2, distance: 80)
        let back = TrainPosition(blockId: block.id, index: 1, distance: 20)
        let position = TrainLocation(front: front, back: back)
                
        // [      >
        //  ---->
        //  b   f
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: block, trainPosition: position, directionOfVisit: .previous, trainForward: true), 60)
        
        // <      ]
        //  ---->
        //  b   f
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: block, trainPosition: position, directionOfVisit: .next, trainForward: true), 60)
        
        // [      >
        //  ----<
        //  b   f
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: block, trainPosition: position, directionOfVisit: .previous, trainForward: false), 60)
        
        // <      ]
        //  ----<
        //  b   f
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: block, trainPosition: position, directionOfVisit: .next, trainForward: false), 60)
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
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: ba, trainPosition: position, directionOfVisit: .previous, trainForward: true), 80)
        
        //    <      ]
        //  ---->
        //  b   f
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: ba, trainPosition: position, directionOfVisit: .next, trainForward: true), 20)
        
        //    <      ]
        //  ----<
        //  b   f
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: ba, trainPosition: position, directionOfVisit: .previous, trainForward: false), 20)
        
        //   [      >
        // ----<
        // b   f
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: ba, trainPosition: position, directionOfVisit: .next, trainForward: false), 80)
    }

    func testOccupationBackBlockOnly() {
        let layout = Layout()
        let tv = TrainVisitor(layout: layout)
        
        let ba = Block()
        ba.length = 100

        let bb = Block()
        bb.length = 100

        let front = TrainPosition(blockId: ba.id, index: 2, distance: 80)
        let back = TrainPosition(blockId: bb.id, index: 1, distance: 20)
        let position = TrainLocation(front: front, back: back)
                
        // [    >
        //    ---->
        //    b   f
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: bb, trainPosition: position, directionOfVisit: .previous, trainForward: true), 80)
        
        // <   ]
        //   ---->
        //   b   f
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: bb, trainPosition: position, directionOfVisit: .next, trainForward: true), 20)
        
        // <      ]
        //     ----<
        //     b   f
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: bb, trainPosition: position, directionOfVisit: .previous, trainForward: false), 20)
        
        // [    >
        //    ----<
        //    b   f
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: bb, trainPosition: position, directionOfVisit: .next, trainForward: false), 80)
    }

    func testOccupationMiddleBlock() {
        // Block that is not the front not the back
        
        let layout = Layout()
        let tv = TrainVisitor(layout: layout)
        
        let ba = Block()
        ba.length = 100
        
        let bb = Block()
        bb.length = 100

        let bc = Block()
        bc.length = 100

        let front = TrainPosition(blockId: ba.id, index: 2, distance: 80)
        let back = TrainPosition(blockId: bc.id, index: 1, distance: 20)
        let position = TrainLocation(front: front, back: back)

        //   [   >
        // --------->
        // b        f
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: bb, trainPosition: position, directionOfVisit: .previous, trainForward: true), 100)
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: bb, trainPosition: position, directionOfVisit: .previous, trainForward: false), 100)
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: bb, trainPosition: position, directionOfVisit: .next, trainForward: true), 100)
        XCTAssertEqual(tv.occupiedLengthOfTrainInBlock(block: bb, trainPosition: position, directionOfVisit: .next, trainForward: false), 100)

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
        
        train.locomotive?.directionForward = true
        block.trainInstance = .init(train.id, .next)
        train.position = .init(front: .init(blockId: block.id, index: 2, distance: 80),
                               back: .init(blockId: block.id, index: 0, distance: 20))
        
        try assert(tv, train: train, remainingTrainLength: 0, blocks: [block])
        
        train.locomotive?.directionForward = false
        block.trainInstance = .init(train.id, .next)
        train.position = .init(front: .init(blockId: block.id, index: 2, distance: 80),
                               back: .init(blockId: block.id, index: 0, distance: 20))
        
        try assert(tv, train: train, remainingTrainLength: 0, blocks: [block])
        
        train.locomotive?.directionForward = true
        block.trainInstance = .init(train.id, .previous)
        train.position = .init(front: .init(blockId: block.id, index: 0, distance: 20),
                               back: .init(blockId: block.id, index: 2, distance: 80))
        
        try assert(tv, train: train, remainingTrainLength: 0, blocks: [block])
        
        train.locomotive?.directionForward = false
        block.trainInstance = .init(train.id, .previous)
        train.position = .init(front: .init(blockId: block.id, index: 0, distance: 20),
                               back: .init(blockId: block.id, index: 2, distance: 80))
        
        try assert(tv, train: train, remainingTrainLength: 0, blocks: [block])
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

        train.position = .init(front: .init(blockId: bb.id, index: 1, distance: 20),
                               back: .init(blockId: ba.id, index: 2, distance: 80))
        
        try assert(tv, train: train, remainingTrainLength: 20, blocks: [bb, ba])
        
        train.position = .init(front: .init(blockId: bb.id, index: 1, distance: 20),
                               back: .init(blockId: ba.id, index: 2, distance: 60))
        
        try assert(tv, train: train, remainingTrainLength: 0, blocks: [bb, ba])

        // ba[  ]>   bb[   ]>
        //     ----------<
        //     b         f
        //     ----------> (direction of visit/occupation filling)
        
        train.locomotive?.directionForward = false
        ba.trainInstance = .init(train.id, .previous)
        bb.trainInstance = .init(train.id, .previous)
        train.block = ba

        train.position = .init(front: .init(blockId: bb.id, index: 1, distance: 20),
                               back: .init(blockId: ba.id, index: 2, distance: 80))
        
        try assert(tv, train: train, remainingTrainLength: 20, blocks: [ba, bb])
        
        train.position = .init(front: .init(blockId: bb.id, index: 1, distance: 20),
                               back: .init(blockId: ba.id, index: 2, distance: 60))
        
        try assert(tv, train: train, remainingTrainLength: 0, blocks: [ba, bb])

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

        train.position = .init(front: .init(blockId: bb.id, index: 1, distance: 80),
                               back: .init(blockId: ba.id, index: 2, distance: 20))
        
        try assert(tv, train: train, remainingTrainLength: 20, blocks: [bb, ba])
        
        train.position = .init(front: .init(blockId: bb.id, index: 1, distance: 80),
                               back: .init(blockId: ba.id, index: 2, distance: 40))

        try assert(tv, train: train, remainingTrainLength: 0, blocks: [bb, ba])

        // ba<[  ]   bb<[   ]
        //      ----------<
        //      b         f
        //      ----------> (direction of visit/occupation filling)

        train.locomotive?.directionForward = false
        ba.trainInstance = .init(train.id, .next)
        bb.trainInstance = .init(train.id, .next)
        train.block = ba

        train.position = .init(front: .init(blockId: bb.id, index: 1, distance: 80),
                               back: .init(blockId: ba.id, index: 2, distance: 20))
        
        try assert(tv, train: train, remainingTrainLength: 20, blocks: [ba, bb])
        
        train.position = .init(front: .init(blockId: bb.id, index: 1, distance: 80),
                               back: .init(blockId: ba.id, index: 2, distance: 40))

        try assert(tv, train: train, remainingTrainLength: 0, blocks: [ba, bb])
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

        train.position = .init(front: .init(blockId: bc.id, index: 1, distance: 20),
                               back: .init(blockId: ba.id, index: 2, distance: 80))
        
        try assert(tv, train: train, remainingTrainLength: 20, blocks: [bc, bb, ba])
        
        train.position = .init(front: .init(blockId: bc.id, index: 1, distance: 20),
                               back: .init(blockId: ba.id, index: 2, distance: 60))
        
        try assert(tv, train: train, remainingTrainLength: 0, blocks: [bc, bb, ba])
        
        // ba[  ]>   bb[   ]>  bc[   ]>
        //     --------------------<
        //     b                   f
        //     --------------------> (direction of visit/occupation filling)
        
        train.locomotive?.directionForward = false
        ba.trainInstance = .init(train.id, .previous)
        bb.trainInstance = .init(train.id, .previous)
        bc.trainInstance = .init(train.id, .previous)
        train.block = ba

        train.position = .init(front: .init(blockId: bc.id, index: 1, distance: 20),
                               back: .init(blockId: ba.id, index: 2, distance: 80))
        
        try assert(tv, train: train, remainingTrainLength: 20, blocks: [ba, bb, bc])
        
        train.position = .init(front: .init(blockId: bc.id, index: 1, distance: 20),
                               back: .init(blockId: ba.id, index: 2, distance: 60))
        
        try assert(tv, train: train, remainingTrainLength: 0, blocks: [ba, bb, bc])

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

        train.position = .init(front: .init(blockId: bc.id, index: 1, distance: 80),
                               back: .init(blockId: ba.id, index: 2, distance: 20))
        
        try assert(tv, train: train, remainingTrainLength: 20, blocks: [bc, bb, ba])
        
        train.position = .init(front: .init(blockId: bc.id, index: 1, distance: 80),
                               back: .init(blockId: ba.id, index: 2, distance: 40))

        try assert(tv, train: train, remainingTrainLength: 0, blocks: [bc, bb, ba])

        // ba<[  ]   bb<[   ]   bc<[   ]
        //      --------------------<
        //      b                   f
        //      --------------------> (direction of visit/occupation filling)

        train.locomotive?.directionForward = false
        ba.trainInstance = .init(train.id, .next)
        bb.trainInstance = .init(train.id, .next)
        bc.trainInstance = .init(train.id, .next)
        train.block = ba

        train.position = .init(front: .init(blockId: bc.id, index: 1, distance: 80),
                               back: .init(blockId: ba.id, index: 2, distance: 20))
        
        try assert(tv, train: train, remainingTrainLength: 20, blocks: [ba, bb, bc])
        
        train.position = .init(front: .init(blockId: bc.id, index: 1, distance: 80),
                               back: .init(blockId: ba.id, index: 2, distance: 40))

        try assert(tv, train: train, remainingTrainLength: 0, blocks: [ba, bb, bc])
        
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

        train.position = .init(front: .init(blockId: bc.id, index: 1, distance: 20),
                               back: .init(blockId: ba.id, index: 2, distance: 20))
        
        try assert(tv, train: train, remainingTrainLength: 20, blocks: [bc, bb, ba])
        
        train.position = .init(front: .init(blockId: bc.id, index: 1, distance: 20),
                               back: .init(blockId: ba.id, index: 2, distance: 40))

        try assert(tv, train: train, remainingTrainLength: 0, blocks: [bc, bb, ba])
    }
    
    private func assert(_ tv: TrainVisitor, train: Train, remainingTrainLength: Double, blocks: [Block]) throws {
        let result = try tv.visit(train: train) { _ in
            
        } turnoutCallback: { turnoutInfo in
            
        } blockCallback: { block, blockAttributes in
        }

        XCTAssertEqual(result.remainingTrainLength, remainingTrainLength, "Remaining train length mismatch")
        XCTAssertEqual(result.blocks.toBlockNames, blocks.toBlockNames, "Visited blocks mismatch")
    }
}

extension Array where Element == ElementVisitor.BlockInfo {
    
    var toBlockNames: [String] {
        self.map { $0.block.name }
    }
    
}

extension Array where Element == Block {
    
    var toBlockNames: [String] {
        self.map { $0.name }
    }
    
}
