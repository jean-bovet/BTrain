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

struct StationView: View {
    
    @Environment(\.undoManager) var undoManager

    @ObservedObject var layout: Layout
        
    @ObservedObject var station: Station

    @State private var selection: String? = nil

    func stepBlockBinding(_ routeItem: Binding<RouteItem>) -> Binding<RouteStepBlock> {
        Binding<RouteStepBlock>(
            get: {
                if case .block(let stepBlock) = routeItem.wrappedValue {
                    return stepBlock
                } else {
                    fatalError()
                }
            },
            set: { newValue in
                routeItem.wrappedValue = .block(newValue)
            }
        )
    }

    var body: some View {
        VStack {
            List($station.elements, selection: $selection) { element in
                StationElementView(layout: layout, element: element)
            }.listStyle(.inset(alternatesRowBackgrounds: true))
            
            HStack {
                Text("\(station.elements.count) elements")
                
                Spacer()
                
                Button("+") {
                    let element = Station.StationElement()
                    station.elements.append(element)
                    undoManager?.registerUndo(withTarget: station, handler: { station in
                        station.elements.removeAll { s in
                            return s.id == element.id
                        }
                    })
                }
                Button("-") {
                    if let element = station.elements.first(where: { $0.id == selection }) {
                        station.elements.removeAll { s in
                            return s.id == element.id
                        }

                        undoManager?.registerUndo(withTarget: station, handler: { station in
                            station.elements.append(element)
                        })
                    }
                }.disabled(selection == nil)
                
                Spacer().fixedSpace()
                                
                MoveUpButtonView(selection: $selection, elements: $station.elements)
                MoveDownButtonView(selection: $selection, elements: $station.elements)

                Spacer().fixedSpace()
            }
            .padding()
        }
    }
    }

struct StationView_Previews: PreviewProvider {
    static var previews: some View {
        StationView(layout: LayoutLoop1().newLayout(), station: Station(id: Identifier<Station>(uuid: "NE"), name: "Neuchatel", elements: []))
    }
}
