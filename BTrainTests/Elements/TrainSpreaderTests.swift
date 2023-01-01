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
    let ls = LayoutSample()

    func testSpreadSinglePart() throws {
        let tv = TrainSpreader(layout: ls.layout)
        try assert(tv: tv, block: ls.b0, distance: 50, direction: .next, lengthOfTrain: 50, expected: [ExpectedBlock(block: ls.b0, parts: [.single(0, 100)])])
        try assert(tv: tv, block: ls.b1, distance: 0, direction: .next, lengthOfTrain: 10, expected: [ExpectedBlock(block: ls.b1, parts: [.single(0, 10)])])
        try assert(tv: tv, block: ls.b1, distance: 20, direction: .next, lengthOfTrain: 20, expected: [ExpectedBlock(block: ls.b1, parts: [.single(0, 40)])])
        try assert(tv: tv, block: ls.b1, distance: 60, direction: .next, lengthOfTrain: 40, expected: [ExpectedBlock(block: ls.b1, parts: [.single(1, 100)])])
        try assert(tv: tv, block: ls.b1, distance: 60, direction: .next, lengthOfTrain: 20, expected: [ExpectedBlock(block: ls.b1, parts: [.single(1, 80)])])
        try assert(tv: tv, block: ls.b2, distance: 20, direction: .previous, lengthOfTrain: 20, expected: [ExpectedBlock(block: ls.b2, parts: [.single(0, 0)])])
    }
    
    func testSpreadTwoParts() throws {
        let tv = TrainSpreader(layout: ls.layout)
        
        try assert(tv: tv, block: ls.b1, distance: 0, direction: .next, lengthOfTrain: 50, expected: [ExpectedBlock(block: ls.b1, parts: [.first(0, 50), .last(1, 50)])])
        try assert(tv: tv, block: ls.b1, distance: 0, direction: .next, lengthOfTrain: 51, expected: [ExpectedBlock(block: ls.b1, parts: [.first(0, 50), .last(1, 51)])])
        try assert(tv: tv, block: ls.b1, distance: 20, direction: .next, lengthOfTrain: 50, expected: [ExpectedBlock(block: ls.b1, parts: [.first(0, 50), .last(1, 70)])])
        try assert(tv: tv, block: ls.b1, distance: 20, direction: .next, lengthOfTrain: 30, expected: [ExpectedBlock(block: ls.b1, parts: [.first(0, 50), .last(1, 50)])])
        
        try assert(tv: tv, block: ls.b2, distance: 50, direction: .previous, lengthOfTrain: 50, expected: [ExpectedBlock(block: ls.b2, parts: [.first(1, 20), .last(0, 0)])])
        try assert(tv: tv, block: ls.b2, distance: 100, direction: .previous, lengthOfTrain: 20, expected: [ExpectedBlock(block: ls.b2, parts: [.first(2, 80), .last(1, 80)])])
        try assert(tv: tv, block: ls.b3, distance: 60, direction: .previous, lengthOfTrain: 80, success: false, expected: [ExpectedBlock(block: ls.b3, parts: [.first(1, 30), .middle(0, 0)])])
    }
    
    func testSpreadTwoBlocks() throws {
        let tv = TrainSpreader(layout: ls.layout)

        try assert(tv: tv, block: ls.b1, distance: 60, direction: .next, lengthOfTrain: 50, expected: [ExpectedBlock(block: ls.b1, parts: [.first(1, 100)]), ExpectedBlock(block: ls.b2, parts: [.last(0, 10)])])
        try assert(tv: tv, block: ls.b1, distance: 100, direction: .next, lengthOfTrain: 20, expected: [ExpectedBlock(block: ls.b1, parts: [.first(1, 100)]), ExpectedBlock(block: ls.b2, parts: [.middle(0, 20), .last(1, 20)])])

        try assert(tv: tv, block: ls.b2, distance: 60, direction: .next, lengthOfTrain: 60, expected: [ExpectedBlock(block: ls.b2, parts: [.first(1, 80), .middle(2, 100)]), ExpectedBlock(block: ls.b3, parts: [.last(2, 90)])])
    }

    struct ExpectedBlock {
        let block: Block
        let parts: [ExpectedPart]
    }
    
    struct ExpectedPart {
        let index: Int
        let first: Bool
        let last: Bool
        let distance: Double
        
        static func single(_ index: Int, _ distance: Double) -> ExpectedPart {
            .init(index: index, first: true, last: true, distance: distance)
        }
        
        static func first(_ index: Int, _ distance: Double) -> ExpectedPart {
            .init(index: index, first: true, last: false, distance: distance)
        }
        
        static func last(_ index: Int, _ distance: Double) -> ExpectedPart {
            .init(index: index, first: false, last: true, distance: distance)
        }

        static func middle(_ index: Int, _ distance: Double) -> ExpectedPart {
            .init(index: index, first: false, last: false, distance: distance)
        }

    }

    private func assert(tv: TrainSpreader, block: Block, distance: Double, direction: Direction, lengthOfTrain: Double, success: Bool = true, expected: [ExpectedBlock]) throws {
        let results = try spread(tv: tv, block: block, distance: distance, direction: direction, lengthOfTrain: lengthOfTrain)
        XCTAssertEqual(results.success, success)

        for (index, block) in results.blocks.enumerated() {
            let parts = block.parts
            let expectedBlock = expected[index]
            XCTAssertEqual(block.block.block, expectedBlock.block)
            XCTAssertEqual(parts.count, expectedBlock.parts.count, "Mismatch in the number of parts")
            
            let expectedParts = expectedBlock.parts
            for (pindex, part) in parts.enumerated() {
                XCTAssertEqual(part.partIndex, expectedParts[pindex].index, "Mismatching part index at part \(pindex)")
                XCTAssertEqual(part.firstPart, expectedParts[pindex].first, "Mismatching first part flag at part \(pindex)")
                XCTAssertEqual(part.lastPart, expectedParts[pindex].last, "Mismatching last part flag at part \(pindex)")
                XCTAssertEqual(part.distance, expectedParts[pindex].distance, "Mismatching distance at part \(pindex)")
            }
        }
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
    
}
