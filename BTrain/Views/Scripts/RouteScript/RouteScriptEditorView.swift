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

struct RouteScriptEditorView: View {
    let doc: LayoutDocument
    let layout: Layout
    @ObservedObject var script: RouteScript

    @State private var showResultsSummary = false
    @State private var validator = RouteScriptValidator()

    var body: some View {
        VStack {
            if script.commands.isEmpty {
                CenteredCustomView {
                    Text("No Commands")
                    Button("+") {
                        script.commands.append(RouteScriptCommand(action: .move))
                    }
                }
            } else {
                List {
                    ForEach($script.commands, id: \.self) { command in
                        RouteScriptLineView(doc: doc, layout: layout, script: script, command: command, commandErrorIds: $validator.commandErrorIds)
                        if let children = command.children {
                            ForEach(children, id: \.self) { command in
                                HStack {
                                    Spacer().fixedSpace()
                                    RouteScriptLineView(doc: doc, layout: layout, script: script, command: command, commandErrorIds: $validator.commandErrorIds)
                                }
                            }
                        }
                    }
                }
                HStack {
                    Button("Verify") {
                        validator.validate(script: script, layout: layout)
                    }

                    switch validator.verifyStatus {
                    case .none:
                        Spacer()

                    case .failure:
                        Text("􀇾")
                        if let errorSummary = validator.errorSummary {
                            Text(errorSummary)
                        }
                        Spacer()

                    case .success:
                        Text("􀁢")

                        Spacer()

                        Button("View Resulting Route") {
                            showResultsSummary.toggle()
                        }
                        .sheet(isPresented: $showResultsSummary, content: {
                            AlertCustomView {
                                VStack(alignment: .leading) {
                                    VStack(alignment: .leading) {
                                        Text("Generated Route:")
                                            .font(.title2)
                                        ScrollView {
                                            Text("\(validator.generatedRouteDescription(layout: layout))")
                                        }.frame(minHeight: 80)
                                    }
                                    VStack(alignment: .leading) {
                                        Text("Resolved Route:")
                                            .font(.title2)
                                        ScrollView {
                                            Text("\(validator.resolvedRouteDescription)")
                                        }.frame(minHeight: 80)
                                    }
                                }
                                .padding()
                                .frame(maxWidth: 600)
                            }
                        })
                    }
                }.padding([.leading, .trailing])
            }
        }
    }
}

struct RouteScriptEditorView_Previews: PreviewProvider {
    static let layout = {
        let layout = Layout()
        let s = RouteScript(name: "Boucle")
        s.commands.append(RouteScriptCommand(action: .move))
        var loop = RouteScriptCommand(action: .loop)
        loop.repeatCount = 2
        loop.children.append(RouteScriptCommand(action: .move))
        loop.children.append(RouteScriptCommand(action: .move))
        s.commands.append(loop)
        layout.routeScripts.add(s)
        return layout
    }()

    static let doc = LayoutDocument(layout: layout)
    
    static var previews: some View {
        Group {
            RouteScriptEditorView(doc: doc, layout: layout, script: layout.routeScripts[0])
        }.previewDisplayName("Route")
        Group {
            RouteScriptEditorView(doc: doc, layout: layout, script: RouteScript())
        }.previewDisplayName("Empty Route")
    }
}
