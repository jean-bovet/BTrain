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

    /// True to display only running trains
    @State private var filterRunningTrains = false

    @Binding var pinnedTrainIds: Set<Identifier<Train>>

    var filteredTrain: [Train] {
        layout.trains.elements.filter { train in
            if filterRunningTrains {
                return train.enabled && train.scheduling != .unmanaged
            } else {
                return train.enabled
            }
        }
    }

    var pinnedTrains: [Train] {
        filteredTrain.filter { train in
            pinnedTrainIds.contains(train.id)
        }
    }

    var trains: [Train] {
        filteredTrain.filter { train in
            !pinnedTrainIds.contains(train.id)
        }
    }

    var body: some View {
        if layout.trains.elements.isEmpty {
            VStack {
                Text("No Trains")
                Button("Add a Train") {
                    document.displaySheetType = .trains
                }
            }
        } else {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    if layout.layoutScripts.elements.count > 0 {
                        TrainControlScriptView(document: document, layout: layout)
                            .padding([.bottom])
                        Divider()
                            .padding([.bottom])
                    }
                    TrainControlActionsView(document: document, layout: layout, filterRunningTrains: $filterRunningTrains)
                }.padding()
                List {
                    if pinnedTrains.count > 0 {
                        ForEach(pinnedTrains, id: \.self) { train in
                            TrainControlContainerView(document: document, train: train, pinnedTrainIds: $pinnedTrainIds)
                            if train.id != pinnedTrains.last?.id {
                                Divider()
                            }
                        }
                        Divider()
                            .frame(height: 2)
                            .overlay(.pink)
                    }
                    ForEach(trains, id: \.self) { train in
                        TrainControlContainerView(document: document, train: train, pinnedTrainIds: $pinnedTrainIds)
                        if train.id != trains.last?.id {
                            Divider()
                        }
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
            TrainControlListView(layout: doc.layout, document: doc, pinnedTrainIds: .constant([]))
        }.previewDisplayName("With Trains")
        Group {
            TrainControlListView(layout: doc.layout, document: doc, pinnedTrainIds: .constant([doc.layout.trains[1].id]))
        }.previewDisplayName("With Trains and Pinned")
        Group {
            TrainControlListView(layout: emptyDoc.layout, document: emptyDoc, pinnedTrainIds: .constant([]))
        }.previewDisplayName("No Trains")
    }
}
