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

struct TrainControlActionsView: View {
    
    @ObservedObject var document: LayoutDocument
    @ObservedObject var layout: Layout
    
    @Binding var filterRunningTrains: Bool
    @State private var selectedLayoutScript: Identifier<LayoutScript>?

    var trainActions: some View {
        HStack {
            Button("􀊋 Start All") {
                document.startAll()
            }.disabled(!document.trainsThatCanBeStarted || !document.power)
            
            Spacer().fixedSpace()

            Button("􀛷 Stop All") {
                document.stopAll()
            }.disabled(!document.trainsThatCanBeStopped)
            
            Spacer().fixedSpace()

            Button("􀊆 Finish All") {
                document.finishAll()
            }.disabled(!document.trainsThatCanBeFinished)
            
            Spacer()

            Button(filterRunningTrains ? "􀌉" : "􀌈") {
                filterRunningTrains.toggle()
            }.buttonStyle(.borderless)
        }
    }
        
    var layoutScriptActions: some View {
        HStack {
            Picker("Script:", selection: $selectedLayoutScript) {
                ForEach(layout.layoutScripts.elements, id:\.self) { script in
                    Text(script.name).tag(script.id as Identifier<LayoutScript>?)
                }
            }
            .labelsHidden()
            .fixedSize()
            .onAppear() {
                selectedLayoutScript = layout.layoutScripts.elements.first?.id
            }

            Spacer().fixedSpace()

            Button("􀊄 Start") {
                document.layoutController.schedule(scriptId: selectedLayoutScript!)
            }.disabled(selectedLayoutScript == nil)

            Spacer().fixedSpace()
            
            Button("􀛷 Stop") {
                document.layoutController.stop(scriptId: selectedLayoutScript!)
            }.disabled(selectedLayoutScript == nil)

            Spacer()
        }.disabled(!document.power)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if layout.layoutScripts.elements.count > 0 {
                layoutScriptActions
                    .padding([.bottom])
                Divider()
                    .padding([.bottom])
            }
            trainActions
        }
    }
}

struct TrainControlActionsView_Previews: PreviewProvider {

    static let doc: LayoutDocument = {
        let d = LayoutDocument(layout: LayoutLoop2().newLayout())
        let s = LayoutScript(uuid: "foo", name: "Demo Loop 1")
        d.layout.layoutScripts.add(s)
        return d
    }()

    static let docEmpty = LayoutDocument(layout: LayoutLoop2().newLayout())

    static var previews: some View {
        Group {
            TrainControlActionsView(document: doc, layout: doc.layout, filterRunningTrains: .constant(true))
        }.previewDisplayName("With Script")
        Group {
            TrainControlActionsView(document: docEmpty, layout: docEmpty.layout, filterRunningTrains: .constant(true))
        }.previewDisplayName("No Script")
    }
}
