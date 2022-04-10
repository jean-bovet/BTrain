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

struct TurnoutListView: View {
    
    @ObservedObject var layout: Layout
    @State private var selection: Identifier<Turnout>? = nil
    @Environment(\.undoManager) var undoManager

    var body: some View {
        HStack {
            VStack {
                Table(selection: $selection) {
                    TableColumn("Enabled") { turnout in
                        UndoProvider(turnout.enabled) { enabled in
                            Toggle("Enabled", isOn: enabled)
                                .labelsHidden()
                        }
                    }.width(80)
                    
                    TableColumn("Name") { turnout in
                        UndoProvider(turnout.name) { name in
                            TextField("Name", text: name)
                                .labelsHidden()
                        }
                    }
                } rows: {
                    ForEach($layout.turnouts) { turnout in
                        TableRow(turnout)
                    }
                }
                HStack {
                    Text("\(layout.turnouts.count) turnouts")
                    
                    Spacer()
                    
                    Button("+") {
                        let turnout = layout.newTurnout(name: "New Turnout", category: .singleLeft)
                        undoManager?.registerUndo(withTarget: layout, handler: { layout in
                            layout.remove(turnoutID: turnout.id)
                        })
                    }
                    
                    Button("-") {
                        if let turnout = layout.turnout(for: selection) {
                            layout.remove(turnoutID: turnout.id)
                            undoManager?.registerUndo(withTarget: layout, handler: { layout in
                                layout.turnouts.append(turnout)
                            })
                        }
                    }.disabled(selection == nil)
                    
                    Spacer().fixedSpace()
                    
                    Button("􀄬") {
                        layout.sortTurnouts()
                    }.help("Sort Turnouts")
                }.padding()
            }.frame(maxWidth: SideListFixedWidth)
            
            if let selection = selection, let turnout = layout.turnout(for: selection) {
                ScrollView {
                    TurnoutDetailsView(layout: layout, turnout: turnout)
                        .padding()
                }
            } else {
                CenteredLabelView(label: "No Selected Turnout")
            }
        }.onAppear {
            if selection == nil {
                selection = layout.turnouts.first?.id
            }
        }
    }
}

struct TurnoutEditListView_Previews: PreviewProvider {

    static var previews: some View {
        TurnoutListView(layout: LayoutCCreator().newLayout())
    }
}
