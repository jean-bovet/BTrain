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

struct RouteView: View {
    
    @Environment(\.undoManager) var undoManager

    @ObservedObject var layout: Layout
        
    @ObservedObject var route: Route

    @State private var selection: String? = nil
    @State private var invalidRoute: Bool?

    var body: some View {
        VStack {
            Table(selection: $selection) {
                TableColumn("Block") { step in
                    UndoProvider(step.blockId) { blockId in
                        Picker("Block:", selection: blockId) {
                            ForEach(layout.blockMap.values, id:\.self) { block in
                                Text("\(block.name) — \(block.category.description)").tag(block.id as Identifier<Block>?)
                            }
                        }.labelsHidden()
                    }
                }
                
                TableColumn("Direction in Block") { step in
                    UndoProvider(step.direction) { direction in
                        Picker("Direction:", selection: direction) {
                            ForEach(Direction.allCases, id:\.self) { direction in
                                Text(direction.description).tag(direction as Direction?)
                            }
                        }
                        .fixedSize()
                        .labelsHidden()
                    }
                }
                
                TableColumn("Wait Time") { step in
                    if let block = layout.block(for: step.blockId.wrappedValue)  {
                        TextField("", value: step.waitingTime, format: .number)
                            .disabled(block.category != .station)
                    }
                }

            } rows: {
                ForEach($route.steps) { step in
                    TableRow(step)
                }
            }
            
            HStack {
                Text("\(route.steps.count) steps")
                
                Spacer()
                
                Button("+") {
                    let step = Route.Step(String(route.steps.count+1), layout.block(at: 0).id, .next)
                    route.steps.append(step)
                    undoManager?.registerUndo(withTarget: route, handler: { route in
                        route.steps.removeAll { s in
                            return s.id == step.id
                        }
                    })
                }
                Button("-") {
                    if let step = route.steps.first(where: { $0.id == selection }) {
                        route.steps.removeAll { s in
                            return s.id == step.id
                        }

                        undoManager?.registerUndo(withTarget: route, handler: { route in
                            route.steps.append(step)
                        })
                    }
                }.disabled(selection == nil)
                
                Spacer().fixedSpace()
                
                Button("􀄨") {
                    if let index = route.steps.firstIndex(where: { $0.id == selection }), index > route.steps.startIndex  {
                        route.steps.swapAt(index, route.steps.index(before: index))
                    }
                }.disabled(selection == nil)
                
                Button("􀄩") {
                    if let index = route.steps.firstIndex(where: { $0.id == selection }), index < route.steps.endIndex  {
                        route.steps.swapAt(index, route.steps.index(after: index))
                    }
                }.disabled(selection == nil)
                
                Spacer().fixedSpace()
                
                HStack {
                    Button("Verify") {
                        validateRoute()
                    }
                    if let invalidRoute = invalidRoute {
                        if invalidRoute {
                            Text("􀇾")
                        } else {
                            Text("􀁢")
                        }
                    }
                }
                
            }
            .padding()
        }
    }
    
    func validateRoute() {
        let diag = LayoutDiagnostic(layout: layout)
        var errors = [DiagnosticError]()
        diag.checkRoutes(&errors)
        invalidRoute = !errors.isEmpty
    }
}

struct RouteView_Previews: PreviewProvider {
    
    static let layout = LayoutLoop2().newLayout()
    
    static var previews: some View {
        RouteView(layout: layout, route: layout.routes[0])
    }
}
