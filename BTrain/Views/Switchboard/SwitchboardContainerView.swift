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

struct SwitchboardContainerView: View {
    
    @ObservedObject var layout: Layout

    let layoutController: LayoutController

    @ObservedObject var document: LayoutDocument

    @ObservedObject var switchboard: SwitchBoard
    
    @ObservedObject var state: SwitchBoard.State
    
    @AppStorage("switchboardWhiteBackground") var whiteBackground = false
        
    /// Background color of the switchboard, which can be white if the appropriate developer flag
    /// is turned on in order to to proper screenshots.
    var backgroundColor: Color {
        if whiteBackground {
            return .white
        } else {
            return Color(NSColor.windowBackgroundColor)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                SwitchboardEditControlsView(layout: layout, state: state, document: document, switchboard: switchboard)
                ScrollView([.horizontal, .vertical]) {
                    if switchboard.isEmpty && !state.editable {
                        VStack {
                            Text("No Elements")
                            
                            HStack {
                                Button("􀈊 Edit Layout") {
                                    state.editable.toggle()
                                }                                
                            }
                        }
                    } else {
                        SwitchBoardView(switchboard: switchboard, state: state, layout: layout, layoutController: layoutController, gestureEnabled: true)
                    }
                }.background(backgroundColor)
            }
            if layout.runtimeError != nil {
                SwitchboardRuntimeErrorView(debugger: document.layoutController.debugger, error: $layout.runtimeError)
            }
        }.sheet(isPresented: $state.trainDroppedInBlockAction) {
            TrainControlSetLocationSheet(layout: layout, controller: document.layoutController, trainDragInfo: state.trainDragInfo, actionSet: .moveOrSet, train: layout.train(for: state.trainDragInfo?.trainId)!)
                .padding()
        }
    }
}

struct OverviewSwitchboardView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutLoop2().newLayout())

    static var previews: some View {
        SwitchboardContainerView(layout: doc.layout, layoutController: doc.layoutController, document: doc, switchboard: doc.switchboard, state: doc.switchboard.state)
    }
}
