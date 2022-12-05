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

    @Binding var pinnedTrainIds: Set<Identifier<Train>>

    /// Keep track of any runtime error related to the train so it can be displayed to the user
    @State private var trainRuntimeError: String?

    var body: some View {
        VStack(alignment: .leading) {
            if let loc = train.locomotive {
                HStack(alignment: .center) {
                    VStack(alignment: .leading) {
                        TrainControlHeaderView(train: train, pinnedTrainIds: $pinnedTrainIds)
                        TrainControlLocationView(controller: document.layoutController, doc: document, layout: document.layout, train: train)
                    }

                    LocomotiveIconView(locomotiveIconManager: document.locomotiveIconManager, loc: loc, size: .medium, hideIfNotDefined: true)
                }

                if train.block != nil {
                    HStack {
                        TrainControlSpeedView(document: document, train: train, loc: loc, speed: loc.speed, trainRuntimeError: $trainRuntimeError)
                        Spacer()
                        TrainControlStateView(train: train, trainRuntimeError: $trainRuntimeError)
                    }

                    TrainControlRouteView(document: document, train: train, trainRuntimeError: $trainRuntimeError)
                }
            } else {
                HStack {
                    TrainControlHeaderView(train: train, pinnedTrainIds: $pinnedTrainIds)
                    Spacer()
                    Text("No Locomotive")
                }
            }
        }
    }
}

struct TrainControlContainerView_Previews: PreviewProvider {
    static let doc1 = LayoutDocument(layout: LayoutLoop1().newLayout())

    static let doc2: LayoutDocument = {
        let layout = LayoutLoop1().newLayout()
        layout.trains[0].block = layout.blocks[0]
        return LayoutDocument(layout: layout)
    }()

    static let doc3: LayoutDocument = {
        let layout = LayoutLoop1().newLayout()
        layout.trains[0].block = layout.blocks[0]
        layout.trains[0].locomotive = nil
        return LayoutDocument(layout: layout)
    }()

    static var previews: some View {
        VStack {
            TrainControlContainerView(document: doc3, train: doc3.layout.trains[0], pinnedTrainIds: .constant([]))
            Divider()
            TrainControlContainerView(document: doc1, train: doc1.layout.trains[0], pinnedTrainIds: .constant([]))
            Divider()
            TrainControlContainerView(document: doc2, train: doc2.layout.trains[0], pinnedTrainIds: .constant([]))
        }
    }
}
