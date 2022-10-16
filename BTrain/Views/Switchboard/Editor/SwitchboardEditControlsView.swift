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

struct SwitchboardEditControlsView: View {
    
    let layout: Layout

    @ObservedObject var state: SwitchBoard.State
    @ObservedObject var document: LayoutDocument
    @ObservedObject var switchboard: SwitchBoard

    @State private var newBlockSheet = false
    @State private var newTurnoutSheet = false

    var body: some View {
        if state.editing {
            HStack {
                Group {
                    Button("􀅼 Block") {
                        newBlockSheet.toggle()
                    }
                    
                    Button("􀅼 Turnout") {
                        newTurnoutSheet.toggle()
                    }
                    
                    if let linkShape = state.selectedShape as? LinkShape {
                        Button("􁀘") {
                            switchboard.toggleControlPoints(linkShape)
                        }
                    }
                }
                
                Spacer().fixedSpace()
                
                Button("􀈑") {
                    switchboard.remove(state.selectedShape!)
                }.disabled(state.selectedShape == nil)
                
                Spacer()
                
                Toggle("Snap to Grid", isOn: $state.snapToGrid)
                Button("Fit Size") {
                    switchboard.fitSize()
                }
                
                Spacer()
                
                Button("Done") {
                    switchboard.doneEditing()
                }
            }.sheet(isPresented: $newBlockSheet) {
                NewBlockSheet(layout: layout)
                    .frame(width: 400)
                    .padding()
            }.sheet(isPresented: $newTurnoutSheet) {
                NewTurnoutSheet(layout: layout)
                    .frame(width: 400)
                    .padding()
            }.padding()
        }        
    }
    
}

struct SwitchboardEditControlsView_Previews: PreviewProvider {
    
    static let doc: LayoutDocument = {
        let doc = LayoutDocument(layout: LayoutLoop2().newLayout())
        doc.switchboard.state.editing = true
        return doc
    }()

    static var previews: some View {
        SwitchboardEditControlsView(layout: doc.layout, state: doc.switchboard.state, document: doc, switchboard: doc.switchboard)
    }
}
