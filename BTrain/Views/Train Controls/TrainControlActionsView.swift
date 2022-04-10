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
    
    @ObservedObject var layout: Layout
    @ObservedObject var document: LayoutDocument
    @State private var error: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button("􀊋 Start All") {
                    document.startAll()
                }.disabled(layout.trainsThatCanBeStarted().isEmpty)
                
                Spacer()
                
                Button("􀛷 Stop All") {
                    do {
                        try document.stopAll()
                        self.error = nil
                    } catch {
                        self.error = error.localizedDescription
                    }
                }.disabled(layout.trainsThatCanBeStopped().isEmpty)
                
                Button("􀊆 Finish All") {
                    do {
                        try document.finishAll()
                        self.error = nil
                    } catch {
                        self.error = error.localizedDescription
                    }
                }.disabled(layout.trainsThatCanBeFinished().isEmpty)
            }
            if let error = error {
                Text(error)
                    .padding([.top])
            }
        }
    }
}

struct TrainControlActionsView_Previews: PreviewProvider {
    static let doc = LayoutDocument(layout: LayoutLoop2().newLayout())

    static var previews: some View {
        TrainControlActionsView(layout: doc.layout, document: doc)
    }
}
