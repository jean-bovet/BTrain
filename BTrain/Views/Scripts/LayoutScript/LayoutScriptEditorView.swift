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

struct LayoutScriptEditorView: View {
    
    let doc: LayoutDocument
    let layout: Layout
    @ObservedObject var script: LayoutScript
        
    var body: some View {
        VStack {
            HStack {
                Text("Name:")
                TextField("", text: $script.name)
            }.padding([.top, .leading, .trailing])
            
            if script.commands.isEmpty {
                CenteredCustomView {
                    Text("No Commands")
                    Button("+") {
                        script.commands.append(LayoutScriptCommand(action: .run))
                    }
                }
            } else {
                List {
                    ForEach($script.commands, id: \.self) { command in
                        LayoutScriptLineView(doc: doc, layout: layout, script: script, command: command)
                        if let children = command.children {
                            ForEach(children, id: \.self) { command in
                                HStack {
                                    Spacer().fixedSpace()
                                    Text("􀄵")
                                    LayoutScriptLineView(doc: doc, layout: layout, script: script, command: command)
                                }
                            }
                        }
                    }
                }
                // TODO: Add verify button to validate that all referenced RouteScript are also valid
            }
        }
    }    
    
}

struct LayoutScriptEditorView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: Layout())
    
    static let layout = {
        let layout = doc.layout
        let s = LayoutScript(name: "Boucle")
        s.commands.append(LayoutScriptCommand(action: .run))
        var loop = LayoutScriptCommand(action: .run)
        loop.children.append(LayoutScriptCommand(action: .run))
        loop.children.append(LayoutScriptCommand(action: .run))
        s.commands.append(loop)
        layout.layoutScripts.add(s)
        return layout
    }()

    static var previews: some View {
        Group {
            LayoutScriptEditorView(doc: doc, layout: layout, script: layout.layoutScripts[0])
        }.previewDisplayName("Script")
        Group {
            LayoutScriptEditorView(doc: doc, layout: layout, script: LayoutScript())
        }.previewDisplayName("Empty Script")
    }
}
