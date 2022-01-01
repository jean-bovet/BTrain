// Copyright 2021 Jean Bovet
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

struct BlockFeedbackView: View {
 
    let layout: Layout
    @ObservedObject var block: Block
    
    var body: some View {
        VStack(alignment: .leading) {
            ForEach($block.feedbacks, id: \.self) { blockFeedback in
                HStack {
                    Picker("Feedback:", selection: blockFeedback.feedbackId) {
                        ForEach(layout.feedbacks, id:\.self) { feedback in
                            Text(feedback.name).tag(feedback.id)
                        }
                    }
                    .labelsHidden()
                    .id(block) // Forces SwiftUI to re-create the picker, otherwise it crashes when the selection changes from a block that has feedbacks to one that does not have any.
                    
                    Button("-") {
                        block.remove(blockFeedback.wrappedValue)
                    }
                }
            }

            HStack {
                Button("+") {
                    block.add(layout.feedbacks[0].id)
                }.disabled(layout.feedbacks.isEmpty)
                Spacer()
            }
        }
    }
    
}

struct BlockFeedbackView_Previews: PreviewProvider {
    
    static let layout = LayoutCCreator().newLayout()
    
    static var previews: some View {
        BlockFeedbackView(layout: layout, block: layout.mutableBlock(at: 0))
    }
}
