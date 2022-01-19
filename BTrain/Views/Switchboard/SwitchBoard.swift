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

import Foundation
import SwiftUI

final class SwitchBoard: ObservableObject {

    final class State: ObservableObject {
        @Published var selectedShape: Shape?
        @Published var editable: Bool = false
        @AppStorage("snapToGrid") var snapToGrid: Bool = true

        @AppStorage("showBlockName") var showBlockName: Bool = false
        @AppStorage("showTurnoutName") var showTurnoutName: Bool = false

        @Published var triggerRedraw: Bool = false // Used to trigger a redraw of the switchboard

        struct TrainDragInfo {
            let trainId: Identifier<Train>
            let blockId: Identifier<Block>
        }

        @Published var trainDragInfo: TrainDragInfo?
        @Published var trainDroppedInBlockAction: Bool = false
    }
        
    let layout: Layout
    let provider: ShapeProviding
    let context: ShapeContext
    let drag: SwitchBoardDragOperation
    let renderer: SwitchBoardRenderer
    let state: State

    @Published var idealSize: CGSize = .zero
    
    var isEmpty: Bool {
        return provider.shapes.isEmpty
    }
            
    init(layout: Layout, provider: ShapeProviding, context: ShapeContext) {
        self.layout = layout
        self.provider = provider
        self.context = context
        
        let renderer = SwitchBoardRenderer(provider: provider, shapeContext: context)
        let state = State()
        self.drag = SwitchBoardDragOperation(layout: layout, state: state, provider: provider, renderer: renderer)
        self.renderer = renderer
        
        self.state = state
        self.idealSize = computeIdealSize()
    }
    
    func computeIdealSize() -> CGSize {
        var width = 0.0
        var height = 0.0
        
        provider.shapes.forEach { shape in
            width = max(width, shape.bounds.maxX)
            height = max(height, shape.bounds.maxY)
        }
        
        return CGSize(width: max(800, width * 1.1), height: max(400, height * 1.1))
    }

    func remove(_ shape: Shape) {
        state.selectedShape = nil
        if let block = shape as? BlockShape {
            layout.remove(blockID: block.block.id)
            provider.remove(block)
        }
        if let turnout = shape as? TurnoutShape {
            layout.remove(turnoutID: turnout.turnout.id)
            provider.remove(turnout)
        }
    }
}
