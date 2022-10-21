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

struct BlockAllFeedbacksView: View {
 
    let layout: Layout
    @ObservedObject var block: Block
    @State private var selection: Block.BlockFeedback.ID?
    
    var body: some View {
        VStack(alignment: .leading) {
            Table(selection: $selection) {
                TableColumn("Feedback") { blockFeedback in
                    Picker("Feedback:", selection: blockFeedback.feedbackId) {
                        ForEach(layout.feedbacks, id:\.self) { feedback in
                            Text(feedback.name).tag(feedback.id)
                        }
                    }
                    .fixedSize()
                    .labelsHidden()
                    .id(block) // SWIFTUI BUG: Forces SwiftUI to re-create the picker, otherwise it crashes when the selection changes from a block that has feedbacks to one that does not have any.
                }

                TableColumn("Distance from Start (cm)") { blockFeedback in
                    UndoProvider(blockFeedback.distance) { distance in
                        TextField("", value: distance, format: .number)
                            .unitMenu(distance)
                            .labelsHidden()
                    }
                }
            } rows: {
                ForEach($block.feedbacks) { block in
                    TableRow(block)
                }
            }.frame(height: 140)
            
            HStack {
                Button("+") {
                    block.add(layout.feedbacks[0].id)
                }.disabled(layout.feedbacks.isEmpty)
                
                Button("-") {
                    block.feedbacks.removeAll(where: {$0.id == selection})
                }.disabled(selection == nil)

                Spacer()
                
                Button("Auto Fill") {
                    block.autoFillFeedbacks()
                }
            }
        }
    }
    
}

struct BlockFeedbackView_Previews: PreviewProvider {
    
    static let layout = LayoutLoop2().newLayout()
    
    static var previews: some View {
        BlockAllFeedbacksView(layout: layout, block: layout.block(at: 0))
    }
}
