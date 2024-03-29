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
        @Published var ephemeralDraggableShape: EphemeralDraggableShape?
        @Published var editing: Bool = false
        @AppStorage("snapToGrid") var snapToGrid: Bool = true

        @AppStorage("showBlockName") var showBlockName: Bool = false
        @AppStorage("showStationName") var showStationName: Bool = false
        @AppStorage("showStationBackground") var showStationBackground: Bool = false
        @AppStorage("showTurnoutName") var showTurnoutName: Bool = false
        @AppStorage("showTrainIcon") var showTrainIcon: Bool = false

        @Published var triggerRedraw: Bool = false // Used to trigger a redraw of the switchboard

        @AppStorage("zoomToFit") var zoomToFit: Bool = false

        struct TrainDragInfo {
            let trainId: Identifier<Train>
            let blockId: Identifier<Block>
        }

        @Published var trainDragInfo: TrainDragInfo?
        @Published var trainDroppedInBlockAction: Bool = false
    }

    let layout: Layout
    let provider: ShapeProvider
    let context: ShapeContext
    let drag: SwitchBoardDragOperation
    let renderer: SwitchBoardRenderer
    let state: State

    @Published var idealSize: CGSize = .zero

    var isEmpty: Bool {
        provider.shapes.filter(\.visible).isEmpty
    }

    init(layout: Layout, provider: ShapeProvider, context: ShapeContext) {
        self.layout = layout
        self.provider = provider
        self.context = context

        let renderer = SwitchBoardRenderer(provider: provider, shapeContext: context)
        let state = State()
        drag = SwitchBoardDragOperation(layout: layout, state: state, provider: provider, renderer: renderer)
        self.renderer = renderer

        self.state = state
        idealSize = fittedRect().size
    }

    func update() {
        provider.updateShapes()
        idealSize = fittedRect().size
    }

    let margin = 40.0

    func fittedRect() -> CGRect {
        if let firstShape = provider.shapes.first {
            var rect = firstShape.bounds
            for shape in provider.shapes {
                rect = rect.union(shape.bounds)
            }
            return rect.insetBy(dx: -margin, dy: -margin).standardized.integral
        } else {
            return CGRect(x: 0, y: 0, width: 800, height: 400)
        }
    }

    func sign(_ number: CGFloat) -> CGFloat {
        if number < 0 {
            return -1
        } else {
            return 1
        }
    }

    static let GridSize = 10.0

    func fitSize() {
        let r = fittedRect()

        // Offset all the shapes so they are in the center of the fitted rectangle
        let offsetX = sign(r.minX) * floor(abs(r.minX) / SwitchBoard.GridSize) * SwitchBoard.GridSize
        let offsetY = sign(r.minY) * floor(abs(r.minY) / SwitchBoard.GridSize) * SwitchBoard.GridSize

        for shape in provider.draggableShapes {
            shape.center = .init(x: shape.center.x - offsetX, y: shape.center.y - offsetY)
        }

        idealSize = r.size
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
        if let link = shape as? LinkShape {
            if let transition = link.transition {
                layout.remove(transitionID: transition.id)
            }
            provider.remove(link)
        }
    }

    func toggleControlPoints(_ shape: LinkShape) {
        provider.toggleControlPoints(shape)
        fitSize()
    }

    func startEditing() {
        provider.showControlPointShapes()
    }

    func doneEditing() {
        provider.shapes.forEach { $0.selected = false }
        provider.hideControlPointShapes()
        state.selectedShape = nil
        state.editing = false
    }
}
