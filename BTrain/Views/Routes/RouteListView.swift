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

struct RouteListView: View {
    
    @Environment(\.undoManager) var undoManager
    
    @ObservedObject var layout: Layout
    
    @State private var selection: Identifier<Route>? = nil

    var routes: [Route] {
        return layout.manualRoutes
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Table(selection: $selection) {
                    TableColumn("Name") { route in
                        TextField("Route", text: route.name)
                            .labelsHidden()
                    }
                } rows: {
                    ForEach($layout.routes.filter({ !$0.wrappedValue.automatic })) { route in
                        TableRow(route)
                    }
                }

                HStack {
                    Text("\(layout.manualRoutes.count) routes")
                    
                    Spacer()
                    
                    Button("+") {
                        let route = layout.newRoute(UUID().uuidString, name: "New Route", [RouteStep]())
                        selection = route.id
                        undoManager?.registerUndo(withTarget: layout, handler: { layout in
                            layout.remove(routeId: route.id)
                        })
                    }
                    Button("-") {
                        let route = layout.route(for: selection!, trainId: nil)!
                        layout.remove(routeId: route.id)
                        undoManager?.registerUndo(withTarget: layout, handler: { layout in
                            layout.routes.append(route)
                        })
                    }.disabled(selection == nil)
                    
                    Spacer().fixedSpace()
                    
                    Button("􀄬") {
                        layout.sortRoutes()
                    }
                }.padding()
            }.frame(maxWidth: SideListFixedWidth)

            if let routeId = selection, let route = layout.route(for: routeId, trainId: nil) {
                RouteView(layout: layout, route: route)
                    .id(routeId) // SWIFTUI BUG: Need to re-create the view for each route otherwise it crashes when switching between certain routes
            } else {
                CenteredLabelView(label: "No Selected Route")
            }
        }.onAppear() {
            if selection == nil {
                selection = layout.routes.first?.id
            }
        }
    }}

struct RouteListView_Previews: PreviewProvider {
    
    static var previews: some View {
        RouteListView(layout: LayoutLoop2().newLayout())
    }

}
