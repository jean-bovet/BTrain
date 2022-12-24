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

struct LocPicker: View {
    let doc: LayoutDocument
    let emptyLabel: String
    @Binding var selectedLoc: Identifier<Locomotive>?

    internal init(doc: LayoutDocument, emptyLabel: String = "", selectedLoc: Binding<Identifier<Locomotive>?>) {
        self.doc = doc
        self.emptyLabel = emptyLabel
        self._selectedLoc = selectedLoc
    }

    var iconSize: CGSize {
        .init(width: 60, height: 20)
    }

    var locomotives: [Locomotive] {
        doc.layout.locomotives.elements.filter(\.enabled)
    }

    var body: some View {
        Picker("Locomotive:", selection: $selectedLoc) {
            Text(emptyLabel).tag(nil as Identifier<Locomotive>?)
            ForEach(locomotives, id: \.self) { loc in
                HStack {
                    Text(loc.name)
                    if let image = doc.locomotiveIconManager.icon(for: loc.id)?.copy(size: iconSize) {
                        Image(nsImage: image)
                    } else {
                        Image(nsImage: NSImage(color: .windowBackgroundColor, size: iconSize))
                    }
                }
                .tag(loc.id as Identifier<Locomotive>?)
                .padding()
            }
        }
    }
}

struct LocPicker_Previews: PreviewProvider {
    static let doc = LayoutDocument(layout: LayoutComplex().newLayout())

    static var previews: some View {
        LocPicker(doc: doc, selectedLoc: .constant(doc.layout.locomotives[0].id))
    }
}
