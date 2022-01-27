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

struct BlockFeedbackDirectionView: View {
    
    let label: String
    let layout: Layout
    
    let defaultFeedback: Identifier<Feedback>?
    
    @Binding var feedback: Identifier<Feedback>?
    
    @ObservedObject var block: Block

    var body: some View {
        HStack {
            UndoProvider($feedback) { feedbackId in
                Picker(label, selection: feedbackId) {
                    if let defaultFeedback = defaultFeedback, let df = layout.feedback(for: defaultFeedback) {
                        Text("\(df.name) (default)").tag(nil as Identifier<Feedback>?)
                    } else {
                        Text("No Feedback").tag(nil as Identifier<Feedback>?)
                    }
                    ForEach(block.feedbacks, id:\.self) { bf in
                        if let candidate = layout.feedback(for: bf.feedbackId) {
                            Text(candidate.name).tag(candidate.id as Identifier<Feedback>?)
                        }
                    }
                }.fixedSize()
            }
            Spacer()
        }
    }
}

struct BlockDirectionFeedbacksView: View {
    
    let layout: Layout
    let direction: Direction
    @ObservedObject var block: Block

    var body: some View {
        Form {
            if direction == .next {
                BlockFeedbackDirectionView(label: "Entry:", layout: layout,
                                           defaultFeedback: block.defaultEntryFeedback(for: .next),
                                           feedback: $block.entryFeedbackNext, block: block)
                BlockFeedbackDirectionView(label: "Brake:", layout: layout,
                                           defaultFeedback: block.defaultBrakeFeedback(for: .next),
                                           feedback: $block.brakeFeedbackNext, block: block)
                BlockFeedbackDirectionView(label: "Stop:", layout: layout,
                                           defaultFeedback: block.defaultStopFeedback(for: .next),
                                           feedback: $block.stopFeedbackNext, block: block)
            } else {
                BlockFeedbackDirectionView(label: "Entry:", layout: layout,
                                           defaultFeedback: block.defaultEntryFeedback(for: .previous),
                                           feedback: $block.entryFeedbackPrevious, block: block)
                BlockFeedbackDirectionView(label: "Brake:", layout: layout,
                                           defaultFeedback: block.defaultBrakeFeedback(for: .previous),
                                           feedback: $block.brakeFeedbackPrevious, block: block)
                BlockFeedbackDirectionView(label: "Stop:", layout: layout,
                                           defaultFeedback: block.defaultStopFeedback(for: .previous),
                                           feedback: $block.stopFeedbackPrevious, block: block)
            }
        }
    }
}

struct BlockDirectionFeedbacksView_Previews: PreviewProvider {
    
    static let layout = LayoutCCreator().newLayout()

    static var previews: some View {
        BlockDirectionFeedbacksView(layout: layout, direction: .next, block: layout.blocks[0])
    }
}
