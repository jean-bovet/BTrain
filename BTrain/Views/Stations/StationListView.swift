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

struct StationListView: View {
    
    @Environment(\.undoManager) var undoManager
    
    @ObservedObject var layout: Layout
    
    @State private var selection: Identifier<Station>? = nil
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Table(selection: $selection) {
                    TableColumn("Name") { station in
                        TextField("Station", text: station.name)
                            .labelsHidden()
                    }
                } rows: {
                    ForEach($layout.stations) { station in
                        TableRow(station)
                    }
                }

                HStack {
                    Text("\(layout.stations.count) stations")
                    
                    Spacer()
                    
                    Button("+") {
                        let station = layout.newStation()
                        selection = station.id
                        undoManager?.registerUndo(withTarget: layout, handler: { layout in
                            layout.remove(stationId: station.id)
                        })
                    }
                    
                    Button("-") {
                        let station = layout.station(for: selection!)!
                        layout.remove(stationId: station.id)
                        undoManager?.registerUndo(withTarget: layout, handler: { layout in
                            layout.stationMap[station.id] = station
                        })
                    }.disabled(selection == nil)
                    
                    Spacer().fixedSpace()
                    
                    Button("􀄬") {
                        layout.sortStations()
                    }
                }.padding()
            }.frame(maxWidth: SideListFixedWidth)

            if let stationId = selection, let station = layout.station(for: stationId) {
                StationView(layout: layout, station: station)
                    .id(stationId) // SWIFTUI BUG: Need to re-create the view for each route otherwise it crashes when switching between certain routes
            } else {
                CenteredLabelView(label: "No Selected Station")
            }
        }.onAppear() {
            if selection == nil {
                selection = layout.stations.first?.id
            }
        }
    }}

struct StationListView_Previews: PreviewProvider {
    static var previews: some View {
        StationListView(layout: LayoutLoop1().newLayout())
    }
}
