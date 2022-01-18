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

struct BlockFeedbacksView: View {
    
    let layout: Layout
    @ObservedObject var block: Block
    
    enum FeedbackSegmentChoices: CaseIterable {
        case all
        case previous
        case next
    }
    @State private var feedbackSegmentSelection: FeedbackSegmentChoices = .all

    var body: some View {
        VStack {
            Picker("Feedbacks", selection: $feedbackSegmentSelection) {
                Text("Feedbacks").tag(FeedbackSegmentChoices.all)
                Text("Previous Direction").tag(FeedbackSegmentChoices.previous)
                Text("Next Direction").tag(FeedbackSegmentChoices.next)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            
            switch(feedbackSegmentSelection) {
            case .all:
                BlockAllFeedbacksView(layout: layout, block: block)
            case .previous:
                BlockDirectionFeedbacksView(layout: layout, direction: .previous, block: block)
            case .next:
                BlockDirectionFeedbacksView(layout: layout, direction: .next, block: block)
            }
        }
    }
}

struct BlockFeedbacksView_Previews: PreviewProvider {
    
    static let layout = LayoutCCreator().newLayout()

    static var previews: some View {
        BlockFeedbacksView(layout: layout, block: layout.blocks[0])
    }
}
