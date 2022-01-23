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

struct TrainControlContainerView: View {
            
    @ObservedObject var document: LayoutDocument
    
    // Observe the train so any changes is reflected in the UX,
    // such as speed changes during automatic route execution.
    @ObservedObject var train: Train
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    Text(train.name).bold()
                    TrainControlLocationView(layout: document.layout, train: train)
                    TrainControlView(document: document, train: train)
                }

                TrainIconView(trainIconManager: document.trainIconManager, train: train, size: .medium)
            }
            if train.blockId != nil {
                TrainControlRouteView(document: document, train: train)
            }
        }
    }
}

struct TrainControlContainerView_Previews: PreviewProvider {
        
    static let doc1: LayoutDocument = LayoutDocument(layout: LayoutACreator().newLayout())

    static let doc2: LayoutDocument = {
        let layout = LayoutACreator().newLayout()
        layout.trains[0].blockId = layout.block(at: 0).id
        return LayoutDocument(layout: layout)
    }()

    static var previews: some View {
        Group {
            TrainControlContainerView(document: doc1, train: doc1.layout.trains[0])
        }
        Group {
            TrainControlContainerView(document: doc2, train: doc2.layout.trains[0])
        }
    }
}
