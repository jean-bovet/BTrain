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
            List(route.steps, selection: $selection) { step in
                switch step {
                case .block(let stepBlock):
                    RouteStepBlockView(layout: layout, stepBlock: stepBlock)
                case .turnout(_):
                    Text("Unsupported")
                }
            }.listStyle(.inset(alternatesRowBackgrounds: true))
            
            HStack {
                Text("\(route.steps.count) steps")
                
                Spacer()
                
                Button("+") {
                    let step = RouteStep_Block(String(route.steps.count+1), layout.block(at: 0).id, .next)
                    route.steps.append(.block(step))
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
