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

struct StationEditingView: View {
    @ObservedObject var layout: Layout

    @State private var selection: Identifier<Station>? = nil

    var body: some View {
        LayoutElementsEditingView(layout: layout, new: {
            Station(id: LayoutIdentity.newIdentity(layout.stations.elements, prefix: .station), name: "New Station", elements: [])
        }, delete: { station in
            layout.stations.remove(station.id)
        }, duplicate: { station in
            Station(id: LayoutIdentity.newIdentity(layout.stations.elements, prefix: .station), name: "\(station.name) copy", elements: station.elements)
        }, sort: {
            layout.stations.elements.sort {
                $0.name < $1.name
            }
        }, elementContainer: $layout.stations, row: { station in
            UndoProvider(station) { station in
                TextField("Name", text: station.name)
                    .labelsHidden()
            }
        }) { station in
            StationView(layout: layout, station: station)
        }
    }
}

struct StationEditingView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigurationSheet(title: "Stations") {
            StationEditingView(layout: LayoutLoop1().newLayout())
        }
    }
}
