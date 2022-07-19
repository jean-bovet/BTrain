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

struct BlockListView: View {
    
    @ObservedObject var layout: Layout
    
    @State private var selection: Identifier<Block>? = nil
    
    @Environment(\.undoManager) var undoManager

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack {
                    Table(selection: $selection) {
                        TableColumn("Enabled") { block in
                            UndoProvider(block.enabled) { enabled in
                                Toggle("Enabled", isOn: enabled)
                                    .labelsHidden()
                            }
                        }.width(80)

                        TableColumn("Name") { block in
                            UndoProvider(block.name) { name in
                                TextField("Name", text: name)
                                    .labelsHidden()
                            }
                        }
                    } rows: {
                        ForEach($layout.blockMap.values) { block in
                            TableRow(block)
                        }
                    }
                    
                    HStack {
                        Text("\(layout.blockMap.count) blocks")

                        Spacer()

                        Button("+") {
                            let block = layout.newBlock(name: "New Block", category: .free)
                            undoManager?.registerUndo(withTarget: layout, handler: { layout in
                                layout.remove(blockID: block.id)
                            })
                        }
                        
                        Button("-") {
                            if let block = layout.block(for: selection) {
                                layout.remove(blockID: block.id)
                                undoManager?.registerUndo(withTarget: layout, handler: { layout in
                                    layout.add([block])
                                })
                            }
                        }.disabled(selection == nil)
                        
                        Spacer().fixedSpace()
                        
                        Button("􀉁") {
                            layout.duplicate(blockId: selection!)
                        }

                        Spacer().fixedSpace()

                        Button("􀄬") {
                            layout.sortBlocks()
                        }
                    }.padding()
                }.frame(maxWidth: SideListFixedWidth)

                if let selection = selection, let block = layout.block(for: selection) {
                    ScrollView {
                        BlockDetailsView(layout: layout, block: block)
                            .padding()
                    }
                } else {
                    CenteredLabelView(label: "No Selected Block")
                }
            }            
        }.onAppear {
            if selection == nil {
                selection = layout.blockIds.first
            }
        }
    }
}

struct BlockEditListView_Previews: PreviewProvider {

    static var previews: some View {
        BlockListView(layout: LayoutLoop2().newLayout())
    }
}
