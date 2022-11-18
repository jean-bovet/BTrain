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

struct BlockEditingView: View {
    @ObservedObject var layout: Layout

    var body: some View {
        LayoutElementsEditingView(layout: layout, new: {
            layout.newBlock(name: "New Block", category: .free)
        }, delete: { block in
            layout.remove(blockID: block.id)
        }, duplicate: { block in
            layout.duplicate(block: block)
        }, sort: {
            layout.blocks.elements.sort {
                $0.name < $1.name
            }
        }, elementContainer: $layout.blocks, row: { block in
            HStack {
                UndoProvider(block) { block in
                    Toggle("Enabled", isOn: block.enabled)
                }

                UndoProvider(block) { block in
                    TextField("Name", text: block.name)
                }
            }.labelsHidden()
        }) { block in
            ScrollView {
                BlockDetailsView(layout: layout, block: block)
                    .padding()
            }
        }
    }
}

struct BlockEditingView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigurationSheet(title: "Blocks") {
            BlockEditingView(layout: LayoutLoop2().newLayout())
        }
    }
}
