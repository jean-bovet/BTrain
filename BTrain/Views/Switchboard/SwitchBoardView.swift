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
        
    // Because SwiftUI only reacts to changes to the object itself and not
    // its children parameters, we require the state of the switchboard
    // to be specified here - although it is accessible via `switchboard.state`.
    @ObservedObject var state: SwitchBoard.State
    
    // The layout is observed for any change
    // that can cause the switchboard to be re-drawn.
    @ObservedObject var layout: Layout

    let layoutController: LayoutController

    // Watch for dark mode to change the color of switchboard
    @Environment(\.colorScheme) var colorScheme

    @AppStorage("fontSize") var fontSize = 12.0
    
    @Environment(\.undoManager) var undoManager

    // Note: we pass `redraw` and `coordinator` to this method, even if unused,
    // in order to force SwitfUI to re-draw the view if one of them change.
    func draw(context: GraphicsContext, darkMode: Bool, coordinator: LayoutController, layout: Layout, state: SwitchBoard.State) {
        switchboard.context.showBlockName = state.showBlockName
        switchboard.context.showStationName = state.showStationName
        switchboard.context.showTurnoutName = state.showTurnoutName
        switchboard.context.fontSize = fontSize
        switchboard.context.darkMode = darkMode
        context.withCGContext { cgContext in
            switchboard.renderer.draw(context: cgContext)
        }
    }
    
    var body: some View {
        Canvas { context, size in
            if switchboard.state.editable {
                context.stroke(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(.gray),
                    style: .init(dash: [5, 10]))
            }

            draw(context: context, darkMode: colorScheme == .dark, coordinator: layoutController, layout: layout, state: switchboard.state)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    switchboard.drag.onDragChanged(location: gesture.location, translation: gesture.translation)
                }
                .onEnded { _ in
                    switchboard.drag.onDragEnded()
                    undoManager?.registerUndo(withTarget: layout, handler: { layout in
                        // TODO: keep track of what has changed
                    })
                }
        )
        .frame(idealWidth: switchboard.idealSize.width, idealHeight: switchboard.idealSize.height)
    }
}

struct SwitchBoardView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: generateLayout())

    static func generateLayout() -> Layout {
        let lt = LayoutCCreator().newLayout()
        
        try! lt.setTrainPosition(lt.trains[0], 1)
        try! lt.setTrainPosition(lt.trains[1], 2)

        try! lt.setTrainToBlock(lt.trains[0].id, lt.block(at: 0).id, direction: .next)
        try! lt.setTrainToBlock(lt.trains[1].id, lt.block(at: 2).id, direction: .next)

        return lt
    }
    
    static var previews: some View {
        SwitchBoardView(switchboard: doc.switchboard,
                        state: doc.switchboard.state,
                        layout: doc.layout,
                        layoutController: doc.layoutController)
            .environmentObject(doc)
            .previewLayout(.fixed(width: 800, height: 600))
    }
}
