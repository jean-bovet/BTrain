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

class SwitchboardTests: XCTestCase {
    var layout: Layout!
    var provider: ShapeProvider!
    var renderer: SwitchBoardRenderer!
    var dragOp: SwitchBoardDragOperation!
    var state: SwitchBoard.State!
    var controller: LayoutController!

    override func setUp() {
        layout = LayoutIncomplete().newLayout()
        XCTAssertEqual(layout.transitions.elements.count, 0)
        controller = LayoutController(layout: layout, switchboard: nil, interface: MarklinInterface(), functionCatalog: nil)

        let context = ShapeContext()
        provider = ShapeProvider(layout: layout, context: context)
        provider.updateShapes()
        renderer = SwitchBoardRenderer(provider: provider, shapeContext: context)
        state = SwitchBoard.State()
        dragOp = SwitchBoardDragOperation(layout: layout,
                                          state: state,
                                          provider: provider,
                                          renderer: renderer)
    }

    func testDragCreateLink() throws {
        state.editing = true
        XCTAssertEqual(provider.shapes.count, 3)

        let b1 = provider.blockShapes[0]
        let b2 = provider.blockShapes[1]
        let t1 = provider.turnoutShapes[0]

        let b1NextSocket = b1.nextSocket.center
        let t1Socket0 = t1.sockets[0].center
        let t1Socket1 = t1.sockets[1].center
        let b2PreviousSocket = b2.previousSocket.center

        // Create link from block1 to turnout

        dragOp.onDragChanged(location: b1.center, translation: .zero)
        dragOp.onDragEnded()

        dragOp.onDragChanged(location: b1NextSocket, translation: .zero)
        dragOp.onDragChanged(location: t1Socket0, translation: b1NextSocket.distance(to: t1Socket0))
        dragOp.onDragEnded()

        XCTAssertEqual(layout.transitions.elements.count, 1)

        let tr1 = layout.transitions[0]
        XCTAssertEqual(tr1.a.block!, b1.block.id)
        XCTAssertEqual(tr1.b.turnout!, t1.turnout.id)

        // Create link from turnout to block2

        dragOp.onDragChanged(location: t1.center, translation: .zero)
        dragOp.onDragEnded()

        dragOp.onDragChanged(location: t1Socket1, translation: .zero)
        dragOp.onDragChanged(location: b2PreviousSocket, translation: t1Socket1.distance(to: b2PreviousSocket))
        dragOp.onDragEnded()

        XCTAssertEqual(layout.transitions.elements.count, 2)

        let tr2 = layout.transitions[1]
        XCTAssertEqual(tr2.a.turnout!, t1.turnout.id)
        XCTAssertEqual(tr2.b.block!, b2.block.id)
    }

    func testDragTrainSameBlock() throws {
        state.editing = false

        let b1 = provider.blockShapes[0]
        let train = layout.trains[0]
        let loc = Locomotive()
        train.locomotive = loc
        b1.block.length = 100
        b1.block.feedbacks[0].distance = 20
        b1.block.feedbacks[1].distance = 80

        try controller.setupTrainToBlock(train, b1.block.id, naturalDirectionInBlock: .next)
        XCTAssertEqual(train.frontBlockId, b1.block.id)
        XCTAssertEqual(train.positions, TrainPositions.both(blockId: b1.block.id, headIndex: b1.block.feedbacks.count, headDistance: 80.after, tailIndex: b1.block.feedbacks.count, tailDistance: 80.after, direction: .next))

        let c = b1.trainCellPath(at: 0).boundingBox.center
        let c2 = b1.trainCellPath(at: 1).boundingBox.center

        dragOp.onDragChanged(location: c, translation: .zero)
        dragOp.onDragChanged(location: c2, translation: c.distance(to: c2))
        dragOp.onDragEnded()

        // Info must be nil because the same block cannot be used as a drop target
        // because it already has a train in it!
        XCTAssertNil(dragOp.state.trainDragInfo)
    }

    func testDragTrainDifferentBlocks() throws {
        state.editing = false

        let b1 = provider.blockShapes[0]
        b1.block.length = 100
        b1.block.feedbacks[0].distance = 20
        b1.block.feedbacks[1].distance = 80

        let b2 = provider.blockShapes[1]
        b2.block.length = 100
        b2.block.feedbacks[0].distance = 20
        b2.block.feedbacks[1].distance = 80

        let train = layout.trains[0]
        let loc = Locomotive()
        train.locomotive = loc
        try controller.setupTrainToBlock(train, b1.block.id, naturalDirectionInBlock: .next)
        XCTAssertEqual(train.frontBlockId, b1.block.id)

        let c = b1.trainCellPath(at: 0).boundingBox.center
        let c2 = b2.trainCellPath(at: 0).boundingBox.center

        dragOp.onDragChanged(location: c, translation: .zero)
        dragOp.onDragChanged(location: c2, translation: c.distance(to: c2))
        dragOp.onDragEnded()

        guard let dragInfo = dragOp.state.trainDragInfo else {
            XCTFail("Info should not be nil")
            return
        }
        try controller.setupTrainToBlock(layout.trains[dragInfo.trainId]!, dragInfo.blockId, naturalDirectionInBlock: Direction.next)

        XCTAssertEqual(train.frontBlockId, b2.block.id)
    }
}
