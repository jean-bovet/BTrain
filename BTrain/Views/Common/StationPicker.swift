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

struct StationPicker: View {
    let layout: Layout
    @Binding var stationId: Identifier<Station>?

    var sortedStationIds: [Identifier<Station>] {
        layout.stations.elements.sorted {
            $0.name < $1.name
        }.map(\.id)
    }

    var body: some View {
        Picker("Station", selection: $stationId) {
            Text("").tag(nil as Identifier<Station>?)
            ForEach(sortedStationIds, id: \.self) { stationId in
                if let station = layout.stations[stationId] {
                    Text(station.name).tag(stationId as Identifier<Station>?)
                } else {
                    Text(stationId.uuid).tag(stationId as Identifier<Station>?)
                }
            }
        }.labelsHidden()
    }
}

struct StationPicker_Previews: PreviewProvider {
    static let doc = LayoutDocument(layout: LayoutComplex().newLayout())

    static var previews: some View {
        StationPicker(layout: doc.layout, stationId: .constant(doc.layout.stations[0].id))
    }
}
