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

struct RouteNewElementSheet: View {
    
    let layout: Layout
    let route: Route
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.undoManager) var undoManager

    enum ElementType {
        case block
        case station
    }
    
    @State private var elementType: ElementType = .block
    
    var body: some View {
        VStack(alignment: .leading) {
            Picker("Element:", selection: $elementType) {
                if layout.blocks.elements.count > 0 {
                    Text("Block").tag(ElementType.block)
                }
                if layout.stations.elements.count > 0 {
                    Text("Station").tag(ElementType.station)
                }
            }
            
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }.keyboardShortcut(.cancelAction)

                Spacer()
                
                Button("Add") {
                    switch elementType {
                    case .block:
                        let step = RouteItemBlock(layout.blocks[0].id, .next)
                        route.partialSteps.append(.block(step))
                        
                        undoManager?.registerUndo(withTarget: route, handler: { route in
                            route.partialSteps.removeAll { s in
                                s.id == step.id
                            }
                        })
                        
                    case .station:
                        if let station = layout.stations.elements.first {
                            let step = RouteItemStation(stationId: station.id)
                            route.partialSteps.append(.station(step))
                            
                            undoManager?.registerUndo(withTarget: route, handler: { route in
                                route.partialSteps.removeAll { s in
                                    s.id == step.id
                                }
                            })
                        }
                    }
                    
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }.padding()
        }
    }
}

struct RouteNewElementSheet_Previews: PreviewProvider {
    
    static let layout = LayoutLoopWithStations().newLayout()
    
    static var previews: some View {
        RouteNewElementSheet(layout: layout, route: layout.routes[0])
    }
}
