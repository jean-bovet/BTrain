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

import SwiftUI

struct SwitchBoardView: View {
        
    let switchboard: SwitchBoard
        
    let containerSize: CGSize
    
    // Because SwiftUI only reacts to changes to the object itself and not
    // its children parameters, we require the state of the switchboard
    // to be specified here - although it is accessible via `switchboard.state`.
    @ObservedObject var state: SwitchBoard.State
    
    // The layout is observed for any change
    // that can cause the switchboard to be re-drawn.
    @ObservedObject var layout: Layout

    let layoutController: LayoutController

    let gestureEnabled: Bool

    // Watch for dark mode to change the color of switchboard
    @Environment(\.colorScheme) var colorScheme

    @AppStorage(SettingsKeys.fontSize) var fontSize = 12.0
    
    @Environment(\.undoManager) var undoManager
    
    // Note: we pass `redraw` and `coordinator` to this method, even if unused,
    // in order to force SwiftUI to re-draw the view if one of them change.
    func draw(context: GraphicsContext, darkMode: Bool, coordinator: LayoutController, layout: Layout, state: SwitchBoard.State, scale: CGFloat) {
        switchboard.context.showBlockName = state.showBlockName
        switchboard.context.showStationName = state.showStationName
        switchboard.context.showTurnoutName = state.showTurnoutName
        switchboard.context.showTrainIcon = state.showTrainIcon
        switchboard.context.fontSize = fontSize
        switchboard.context.darkMode = darkMode
        switchboard.context.editing = state.editing
        switchboard.context.scale = scale
        context.withCGContext { cgContext in
            cgContext.scaleBy(x: switchboard.context.scale, y: switchboard.context.scale)
            switchboard.renderer.draw(context: cgContext)
        }
    }
    
    var body: some View {
        Canvas { context, size in
            if switchboard.state.editing {
                context.stroke(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(.gray),
                    style: .init(dash: [5, 10]))
            }

            draw(context: context, darkMode: colorScheme == .dark, coordinator: layoutController, layout: layout, state: switchboard.state, scale: scale(containerSize: containerSize))
        }
        .if(gestureEnabled) {
            $0.gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let scale = scale(containerSize: containerSize)
                        switchboard.drag.onDragChanged(location: gesture.location.scaledBy(value: 1 / scale), translation: gesture.translation.scaledBy(value: 1 / scale))
                    }
                    .onEnded { _ in
                        switchboard.drag.onDragEnded()
                        undoManager?.registerUndo(withTarget: layout, handler: { layout in
                            switchboard.drag.restoreState()
                        })
                    }
            )
        }
        .if(!state.zoomToFit) {
            $0.frame(idealWidth: switchboard.idealSize.width, idealHeight: switchboard.idealSize.height)
        }
        .if(state.zoomToFit) {
            $0.frame(idealWidth: containerSize.width, idealHeight: containerSize.height)
        }
    }
    
    func scale(containerSize: CGSize) -> CGFloat {
        let scale: CGFloat
        if state.zoomToFit {
            scale = min(containerSize.width / switchboard.idealSize.width, containerSize.height / switchboard.idealSize.height)
        } else {
            scale = 1.0
        }
        return scale
    }

}

struct SwitchBoardView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: generateLayout())

    static func generateLayout() -> Layout {
        let lt = LayoutLoop2().newLayout()
        
        try! doc.layoutController.setTrainPosition(lt.trains[0], 1)
        try! doc.layoutController.setTrainPosition(lt.trains[1], 2)

        try! doc.layoutController.setTrainToBlock(lt.trains[0], lt.block(at: 0).id, direction: .next)
        try! doc.layoutController.setTrainToBlock(lt.trains[1], lt.block(at: 2).id, direction: .next)

        return lt
    }
    
    static var previews: some View {
        SwitchBoardView(switchboard: doc.switchboard, containerSize: .init(width: 800, height: 600),
                        state: doc.switchboard.state,
                        layout: doc.layout,
                        layoutController: doc.layoutController,
                        gestureEnabled: true)
            .environmentObject(doc)
            .previewLayout(.fixed(width: 800, height: 600))
    }
}
