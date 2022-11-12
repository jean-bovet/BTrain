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

struct BlockPicker: View {
    
    let layout: Layout
    @Binding var blockId: Identifier<Block>?
    
    var sortedBlockIds: [Identifier<Block>] {
        layout.blocks.sorted {
            $0.name < $1.name
        }.map {
            $0.id
        }
    }
    
    var body: some View {
        Picker("Block", selection: $blockId) {
            Text("").tag(nil as Identifier<Block>?)
            ForEach(sortedBlockIds, id:\.self) { blockId in
                if let block = layout.block(for: blockId) {
                    Text(block.name).tag(blockId as Identifier<Block>?)
                } else {
                    Text(blockId.uuid).tag(blockId as Identifier<Block>?)
                }
            }
        }.labelsHidden()
    }
}

struct BlockPicker_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutComplex().newLayout())

    static var previews: some View {
        BlockPicker(layout: doc.layout, blockId: .constant(doc.layout.blockIds[0]))
    }
}
