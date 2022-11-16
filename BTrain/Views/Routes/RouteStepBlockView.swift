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

struct RouteStepBlockView: View {
    
    let layout: Layout
    @Binding var stepBlock: RouteItemBlock
    
    var body: some View {
        HStack {
            UndoProvider($stepBlock.blockId) { blockId in
                Picker("Block:", selection: blockId) {
                    ForEach(layout.blocks.elements, id:\.self) { block in
                        Text("\(block.name) — \(block.category.description)").tag(block.id as Identifier<Block>)
                    }
                }
            }
            
            UndoProvider($stepBlock.direction) { direction in
                Picker("Direction:", selection: direction) {
                    ForEach(Direction.allCases, id:\.self) { direction in
                        Text(direction.description).tag(direction as Direction?)
                    }
                }
                .fixedSize()
            }
            
            if let block = layout.blocks[stepBlock.blockId]  {
                Text("Waiting Time:")
                TextField("", value: $stepBlock.waitingTime, format: .number)
                    .disabled(block.category != .station)
                    .textFieldStyle(.squareBorder)
                    .unitStyle("s")
            }
        }
    }
}

struct RouteStepBlockView_Previews: PreviewProvider {
    
    static let layout = LayoutLoop2().newLayout()

    static var previews: some View {
        RouteStepBlockView(layout: layout, stepBlock: .constant(layout.routes[0].blockSteps[0]))
    }
}
