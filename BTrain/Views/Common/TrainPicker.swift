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

struct TrainPicker: View {
    let doc: LayoutDocument
    @Binding var selectedTrain: Identifier<Train>?

    var iconSize: CGSize {
        .init(width: 60, height: 20)
    }

    var trains: [Train] {
        doc.layout.trains.elements.filter { $0.enabled }
    }

    var body: some View {
        Picker("Train:", selection: $selectedTrain) {
            ForEach(trains, id: \.self) { train in
                HStack {
                    Text(train.name)
                    if let loc = train.locomotive, let image = doc.locomotiveIconManager.icon(for: loc.id)?.copy(size: iconSize) {
                        Image(nsImage: image)
                    } else {
                        Image(nsImage: NSImage(color: .windowBackgroundColor, size: iconSize))
                    }
                }
                .tag(train.id as Identifier<Train>?)
                .padding()
            }
        }
    }
}

struct TrainPicker_Previews: PreviewProvider {
    static let doc = LayoutDocument(layout: LayoutComplex().newLayout())

    static var previews: some View {
        TrainPicker(doc: doc, selectedTrain: .constant(doc.layout.trains[0].id))
    }
}
