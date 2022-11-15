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

struct RouteScriptListView: View {
    
    @Environment(\.undoManager) var undoManager

    @ObservedObject var layout: Layout
    
    @State private var selection: Identifier<RouteScript>?

    var scriptList: some View {
        VStack(alignment: .leading) {
            Table(selection: $selection) {
                TableColumn("Name") { route in
                    TextField("Script", text: route.name)
                        .labelsHidden()
                }
            } rows: {
                ForEach($layout.routeScripts.elements) { route in
                    TableRow(route)
                }
            }
            
            HStack {
                Text("\(layout.routeScripts.elements.count) scripts")
                
                Spacer()
                
                Button("+") {
                    let script = layout.routeScripts.add(RouteScript())
                    selection = script.id
                    undoManager?.registerUndo(withTarget: layout, handler: { layout in
                        layout.routeScripts.remove(script.id)
                    })
                }
                Button("-") {
                    let script = layout.routeScripts[selection]!
                    layout.routeScripts.remove(script.id)
                    undoManager?.registerUndo(withTarget: layout, handler: { layout in
                        layout.routeScripts.add(script)
                    })
                }.disabled(selection == nil)
                
                Spacer().fixedSpace()

                Button("􀉁") {
                    layout.routeScripts.duplicate(selection!)
                }.disabled(selection == nil)

                Spacer().fixedSpace()
                
                Button("􀄬") {
                    layout.routeScripts.sort()
                }
            }.padding([.leading])
        }
        .onAppear {
            if selection == nil {
                selection = layout.routeScripts[0].id
            }
        }.onDisappear() {
            layout.updateRoutesUsingRouteScripts()
        }
    }
    
    var body: some View {
        HStack(alignment: .top) {
            scriptList
                .frame(maxWidth: SideListFixedWidth)
            if let script = layout.routeScripts[selection] {
                RouteScriptEditorView(layout: layout, script: script)
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
                RouteScriptListView(layout: ScriptView_Previews.layout)
            }
        }
        Group {
            ConfigurationSheet(title: "Scripts") {
                RouteScriptListView(layout: Layout())
            }
        }.previewDisplayName("Empty")
    }
}
