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

struct TrainControlListView: View {
    
    // Note: necessary to have the layout as a separate property in order for SwiftUI to detect changes
    @ObservedObject var layout: Layout
    @ObservedObject var document: LayoutDocument
    @State private var filterRunningTrains = false
    
    var trains: [Train] {
        layout.trains.filter { train in
            if filterRunningTrains {
                return train.enabled && train.scheduling != .unmanaged
            } else {
                return train.enabled
            }
        }
    }
    var body: some View {
        if layout.trains.isEmpty {
            VStack {
                Text("No Trains")
                Button("Add a Train") {
                    document.selectedView = .trains
                }
            }
        } else {
            VStack(spacing: 0) {
                TrainControlActionsView(document: document, filterRunningTrains: $filterRunningTrains)
                    .padding()
                List {
                    ForEach(trains, id:\.self) { train in
                        TrainControlContainerView(document: document, train: train)
                        Divider()
                    }
                }
            }
        }
    }
}

struct TrainControlListView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutLoop2().newLayout())
    static let emptyDoc = LayoutDocument(layout: Layout())

    static var previews: some View {
        Group {
            TrainControlListView(layout: doc.layout, document: doc)
        }
        Group {
            TrainControlListView(layout: emptyDoc.layout, document: emptyDoc)
        }
    }
}
