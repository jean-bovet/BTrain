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

struct LayoutScriptCommandView: View {

    let doc: LayoutDocument
    let layout: Layout
    
    @ObservedObject var script: LayoutScript
    @Binding var command: LayoutScriptCommand
    
    var body: some View {
        HStack {
            Text("Run train")
            TrainPicker(doc: doc, selectedTrain: $command.train)
                .labelsHidden()
                .fixedSize()
            
            Text("with route")
            Picker("Route:", selection: $command.route) {
                ForEach(layout.routeScripts.elements, id:\.self) { item in
                    Text(item.name).tag(item.id as Identifier<RouteScript>?)
                }
            }
            .labelsHidden()
            .fixedSize()
            
            Button("􀁌") {
                script.commands.insert(source: LayoutScriptCommand(action: .run), target: command, position: .after)
            }.buttonStyle(.borderless)
            
            Button("􀁎") {
                script.commands.remove(source: command)
            }.buttonStyle(.borderless)
        }
    }
}

struct LayoutScriptCommandView_Previews: PreviewProvider {
    static let doc = LayoutDocument(layout: LayoutComplex().newLayout())
    static let script = LayoutScript()
    
    static let run = LayoutScriptCommand(action: .run)
    
    static let commands = [run]
    
    static var previews: some View {
        VStack(alignment: .leading) {
            ForEach(commands, id:\.self) { command in
                LayoutScriptCommandView(doc: doc, layout: doc.layout, script: script, command: .constant(command))
                    .fixedSize()
            }
        }
    }}
