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

struct ScriptListView: View {
    
    @Environment(\.undoManager) var undoManager

    @ObservedObject var layout: Layout
    
    @State private var selection: Identifier<Script>?

    var scriptList: some View {
        VStack(alignment: .leading) {
            Table(selection: $selection) {
                TableColumn("Name") { route in
                    TextField("Script", text: route.name)
                        .labelsHidden()
                }
            } rows: {
                ForEach($layout.scripts) { route in
                    TableRow(route)
                }
            }
            
            HStack {
                Text("\(layout.scripts.count) scripts")
                
                Spacer()
                
                Button("+") {
                    let script = layout.newScript()
                    selection = script.id
                    undoManager?.registerUndo(withTarget: layout, handler: { layout in
                        layout.remove(scriptId: script.id)
                    })
                }
                Button("-") {
                    let script = layout.script(for: selection)!
                    layout.remove(scriptId: script.id)
                    undoManager?.registerUndo(withTarget: layout, handler: { layout in
                        layout.addScript(script: script)
                    })
                }.disabled(selection == nil)
                
                Spacer().fixedSpace()

                Button("􀉁") {
                    layout.duplicate(scriptId: selection!)
                }.disabled(selection == nil)

                Spacer().fixedSpace()
                
                Button("􀄬") {
                    layout.sortScript()
                }
            }.padding([.leading])
        }
        .onAppear {
            if selection == nil {
                selection = layout.scripts.first?.id
            }
        }.onDisappear() {
            layout.convertScriptsToRoute()
        }
    }
    
    var body: some View {
        HStack(alignment: .top) {
            scriptList
                .frame(maxWidth: SideListFixedWidth)
            if let script = layout.script(for: selection) {
                ScriptEditorView(layout: layout, script: script)
            } else {
                CenteredLabelView(label: "No Selected Script")
            }
        }
    }
}

struct ScriptListView_Previews: PreviewProvider {
        
    static var previews: some View {
        Group {
            ConfigurationSheet(title: "Scripts") {
                ScriptListView(layout: ScriptView_Previews.layout)
            }
        }
        Group {
            ConfigurationSheet(title: "Scripts") {
                ScriptListView(layout: Layout())
            }
        }.previewDisplayName("Empty")
    }
}
