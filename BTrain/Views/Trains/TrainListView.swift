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

struct TrainListView: View {
    
    // Note: necesary to have the layout as a separate property in order for SwiftUI to detect changes
    @ObservedObject var layout: Layout
    @ObservedObject var document: LayoutDocument

    var body: some View {
        if layout.trains.isEmpty {
            HStack {
                Text("No Locomotives")
                Button("􀈄") {
                    document.discoverLocomotiveConfirmation.toggle()
                }
            }
        } else {
            List {
                ForEach(layout.mutableTrains.filter({$0.enabled}), id:\.self) { train in
                    Text(train.name)
                    TrainView(document: document, train: train)
                    Divider()
                }
            }
        }
    }
}

struct TrainListView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutCCreator().newLayout())

    static var previews: some View {
        TrainListView(layout: doc.layout, document: doc)
    }
}
