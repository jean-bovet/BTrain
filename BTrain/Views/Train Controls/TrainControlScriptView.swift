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

struct TrainControlScriptView: View {

    @ObservedObject var document: LayoutDocument
    @ObservedObject var layout: Layout
    @State private var selectedLayoutScript: Identifier<LayoutScript>?

    var body: some View {
        HStack {
            Picker("Script:", selection: $selectedLayoutScript) {
                ForEach(layout.layoutScripts.elements, id:\.self) { script in
                    Text(script.name).tag(script.id as Identifier<LayoutScript>?)
                }
            }
            .disabled(document.layoutController.isRunning(scriptId: selectedLayoutScript))
            .labelsHidden()
            .fixedSize()
            .onAppear() {
                selectedLayoutScript = layout.layoutScripts.elements.first?.id
            }
            
            Spacer().fixedSpace()
            
            Button("􀊄 Start") {
                document.layoutController.schedule(scriptId: selectedLayoutScript!)
            }.disabled(selectedLayoutScript == nil || document.layoutController.isRunning(scriptId: selectedLayoutScript))
            
            Spacer().fixedSpace()
            
            Button("􀛷 Stop") {
                try? document.layoutController.stop(scriptId: selectedLayoutScript!)
            }.disabled(selectedLayoutScript == nil || !document.layoutController.isRunning(scriptId: selectedLayoutScript))
            
            Spacer()
        }.disabled(!document.power)
    }
    
}


struct TrainControlScriptView_Previews: PreviewProvider {
    
    static let doc: LayoutDocument = {
        let d = LayoutDocument(layout: LayoutLoop2().newLayout())
        let s = LayoutScript(uuid: "foo", name: "Demo Loop 1")
        d.layout.layoutScripts.add(s)
        return d
    }()

    static let docEmpty = LayoutDocument(layout: LayoutLoop2().newLayout())

    static var previews: some View {
        Group {
            TrainControlScriptView(document: doc, layout: doc.layout)
        }.previewDisplayName("With Script")
        Group {
            TrainControlScriptView(document: docEmpty, layout: docEmpty.layout)
        }.previewDisplayName("No Script")
    }
}
