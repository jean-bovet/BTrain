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

struct TrainEditingView: View {
    
    @ObservedObject var document: LayoutDocument
    @ObservedObject var layout: Layout
    
    var body: some View {
        LayoutElementsEditingView(layout: layout, new: {
            layout.newTrain()
        }, delete: { train in
            layout.delete(trainId: train.id)
        }, duplicate: { train in
            layout.duplicate(train: train)
        }, sort: {
            layout.trains.elements.sort {
                $0.name < $1.name
            }
        }, elementContainer: $layout.trains, row: { train in
            HStack {
                UndoProvider(train) { train in
                    Toggle("Enabled", isOn: train.enabled)
                }
                if let image = document.locomotiveIconManager.icon(for: train.wrappedValue.locomotive?.id) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 25)
                }
                UndoProvider(train) { train in
                    TextField("Name", text: train.name)
                }
            }.labelsHidden()
        }) { train in
            ScrollView {
                TrainDetailsView(document: document, train: train)
                    .padding()
            }
        }
    }

}

struct TrainListView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutLoop2().newLayout())
    
    static var previews: some View {
        ConfigurationSheet(title: "Trains") {
            TrainEditingView(document: doc, layout: doc.layout)
        }
    }
}
