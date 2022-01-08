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

struct OverviewSwitchboardView: View {
    
    @ObservedObject var layout: Layout

    let coordinator: LayoutCoordinator

    @ObservedObject var document: LayoutDocument

    @ObservedObject var switchboard: SwitchBoard
    
    @ObservedObject var state: SwitchBoard.State
    
    var body: some View {
        VStack {
            SwitchboardEditControlsView(layout: layout, state: state, document: document, switchboard: switchboard)
            ScrollView([.horizontal, .vertical]) {
                if switchboard.isEmpty && !state.editable {
                    VStack {
                        Text("No Elements")
                                             
                        HStack {
                            Button("Edit Layout 􀈊") {
                                state.editable.toggle()
                            }
                            
                            Button("Import Predefined Layout 􀈄") {
                                document.importPredefinedLayout.toggle()
                            }
                        }
                    }
                } else {
                    SwitchBoardView(switchboard: switchboard, state: state, layout: layout, coordinator: coordinator)
                }
            }.background(Color(NSColor.windowBackgroundColor))
            if layout.runtimeError != nil {
                LayoutRuntimeErrorView(error: $layout.runtimeError)
            }
        }.sheet(isPresented: $state.trainDroppedInBlockAction) {
            TrainDropActionSheet(layout: layout, trainDragInfo: state.trainDragInfo!, coordinator: document.coordinator)
                .fixedSize(horizontal: true, vertical: false)
                .padding()
        }
    }
}

struct OverviewSwitchboardView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutCCreator().newLayout())

    static var previews: some View {
        OverviewSwitchboardView(layout: doc.layout, coordinator: doc.coordinator, document: doc, switchboard: doc.switchboard, state: doc.switchboard.state)
    }
}
