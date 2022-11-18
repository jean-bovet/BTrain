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

struct DeveloperView: View {
    let doc: LayoutDocument

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var refresh = false

    var body: some View {
        Table {
            TableColumn("Key") { metric in
                Text("\(metric.id)")
            }
            TableColumn("Value") { metric in
                Text("\(metric.value)")
            }
        } rows: {
            ForEach(doc.layoutController.metrics) { metric in
                TableRow(metric)
            }
        }.onReceive(timer) { _ in
            refresh.toggle()
        }.background(refresh ? .clear : .clear)
    }
}

struct DeveloperView_Previews: PreviewProvider {
    static let doc = LayoutDocument(layout: LayoutYard().newLayout())

    static var previews: some View {
        DeveloperView(doc: doc)
    }
}
