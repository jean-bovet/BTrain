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

struct FeedbackMonitorView: View {
    
    @ObservedObject var layout: Layout

    let columns = [
        GridItem(.adaptive(minimum: 100))
    ]

    var feedbacks: [Feedback] {
        return layout.feedbacks.compactMap { $0 }.sorted { m1, m2 in
            if m1.deviceID < m2.deviceID {
                return true
            } else if m1.deviceID == m2.deviceID {
                return m1.contactID <= m2.contactID
            } else {
                return false
            }
        }
    }

    var body: some View {
        List {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(feedbacks, id: \.self) { item in
                    FeedbackView(label: "\(item.deviceID):\(item.contactID)", state: item.detected)
                        .onTapGesture {
                            item.detected.toggle()
                        }
                }
            }
        }
    }
}

struct FeedbackGridView_Previews: PreviewProvider {
    
    static var previews: some View {
        FeedbackMonitorView(layout: LayoutCCreator().newLayout())
    }
}
