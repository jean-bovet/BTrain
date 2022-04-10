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

class SwitchboardTests: XCTestCase {

    var layout: Layout!
    var provider: ShapeProvider!
    var renderer: SwitchBoardRenderer!
    var dragOp: SwitchBoardDragOperation!
    var state: SwitchBoard.State!
    var controller: LayoutController!
    
    override func setUp() {
        layout = LayoutIncomplete().newLayout()
        XCTAssertEqual(layout.transitions.count, 0)
        controller = LayoutController(layout: layout, switchboard: nil, interface: MarklinInterface())
        
        let context = ShapeContext()
        provider = ShapeProvider(layout: layout, context: context)
        renderer = SwitchBoardRenderer(provider: provider, shapeContext: context)
        state = SwitchBoard.State()
        dragOp = SwitchBoardDragOperation(layout: layout,
                                          state: state,
                                          provider: provider,
                                          renderer: renderer)
    }
    
    func testDragCreateLink() throws {
        state.editable = true
        XCTAssertEqual(provider.shapes.count, 5)
        
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
        
        XCTAssertEqual(layout.transitions.count, 1)
        
        let tr1 = layout.transitions[0]
        XCTAssertEqual(tr1.a.block!, b1.block.id)
        XCTAssertEqual(tr1.b.turnout!, t1.turnout.id)
        
        // Create link from turnout to block2
        
        dragOp.onDragChanged(location: t1.center, translation: .zero)
        dragOp.onDragEnded()
        
        dragOp.onDragChanged(location: t1Socket1, translation: .zero)
        dragOp.onDragChanged(location: b2PreviousSocket, translation: t1Socket1.distance(to: b2PreviousSocket))
        dragOp.onDragEnded()
        
        XCTAssertEqual(layout.transitions.count, 2)
        
        let tr2 = layout.transitions[1]
        XCTAssertEqual(tr2.a.turnout!, t1.turnout.id)
        XCTAssertEqual(tr2.b.block!, b2.block.id)
    }
    
    func testDragTrainSameBlock() throws {
        state.editable = false

        let b1 = provider.blockShapes[0]
        let train = layout.trains[0]
        
        try layout.setTrainToBlock(train.id, b1.block.id, direction: .next)
        XCTAssertEqual(train.blockId, b1.block.id)
        XCTAssertEqual(train.position, 0)

        provider.trainShapes[0].updatePosition()
        
        let c = b1.trainPath(at: 0).boundingBox.center
        let c2 = b1.trainPath(at: 1).boundingBox.center

        dragOp.onDragChanged(location: c, translation: .zero)
        dragOp.onDragChanged(location: c2, translation: c.distance(to: c2))
        dragOp.onDragEnded()
                
        let dragInfo = dragOp.state.trainDragInfo!
        try? layout.setTrainToBlock(dragInfo.trainId, dragInfo.blockId, direction: .next)

        XCTAssertEqual(train.blockId, b1.block.id)
        XCTAssertEqual(train.position, 0)
    }
    
    func testDragTrainDifferentBlocks() throws {
        state.editable = false

        let b1 = provider.blockShapes[0]
        let b2 = provider.blockShapes[1]

        let train = layout.trains[0]
        try layout.setTrainToBlock(train.id, b1.block.id, direction: .next)
        XCTAssertEqual(train.blockId, b1.block.id)

        provider.trainShapes[0].updatePosition()
        
        let c = b1.trainPath(at: 0).boundingBox.center
        let c2 = b2.trainPath(at: 0).boundingBox.center

        dragOp.onDragChanged(location: c, translation: .zero)
        dragOp.onDragChanged(location: c2, translation: c.distance(to: c2))
        dragOp.onDragEnded()
        
        guard let dragInfo = dragOp.state.trainDragInfo else {
            XCTFail("Info should not be nil")
            return
        }
        try? layout.setTrainToBlock(dragInfo.trainId, dragInfo.blockId, direction: Direction.next)

        XCTAssertEqual(train.blockId, b2.block.id)
    }

}
