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
    
    struct RouteError {
        let resolverErrors: [GraphPathFinder.ResolverError]
        let valid: Bool
    }
    
    @Environment(\.undoManager) var undoManager

    @ObservedObject var layout: Layout
        
    @ObservedObject var route: Route

    @State private var selection: String?
    @State private var routeError: RouteError?

    @State private var showAddRouteElementSheet = false
        
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
    
    func stepStationBinding(_ routeItem: Binding<RouteItem>) -> Binding<RouteStepStation> {
        Binding<RouteStepStation>(
            get: {
                if case .station(let stepStation) = routeItem.wrappedValue {
                    return stepStation
                } else {
                    fatalError()
                }
            },
            set: { newValue in
                routeItem.wrappedValue = .station(newValue)
            }
        )
    }

    func stepError(_ step: RouteItem, _ index: Int?) -> Bool {
        guard let index = index else {
            return false
        }

        guard let routeError = routeError else {
            return false
        }

        for error in routeError.resolverErrors {
            if error.to == index {
                return true
            }
        }
        
        return false
    }
    
    var body: some View {
        VStack {
            List($route.steps, selection: $selection) { step in
                let unwrappedStep = step.wrappedValue
                let index = route.steps.firstIndex(of: unwrappedStep)
                let stepError = stepError(unwrappedStep, index)
                HStack {
                    if stepError {
                        Text("􀇾").foregroundColor(.red)
                    }
                    switch unwrappedStep {
                    case .block(_):
                        RouteStepBlockView(layout: layout, stepBlock: stepBlockBinding(step))
                    case .turnout, .station:
                        RouteStepStationView(layout: layout, stepStation: stepStationBinding(step))
                    }
                }
            }.listStyle(.inset(alternatesRowBackgrounds: true))
            
            HStack {
                Text("\(route.steps.count) steps")
                
                Spacer()
                
                Button("+") {
                    showAddRouteElementSheet.toggle()
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
                
                MoveUpButtonView(selection: $selection, elements: $route.steps)
                MoveDownButtonView(selection: $selection, elements: $route.steps)

                Spacer().fixedSpace()
                
                HStack {
                    Button("Verify") {
                        validateRoute()
                    }
                    if let routeError = routeError {
                        if routeError.valid {
                            Text("􀁢")
                        } else {
                            Text("􀇾")
                        }
                    }
                }
                
            }
            .padding()
        }.sheet(isPresented: $showAddRouteElementSheet) {
            RouteNewElementSheet(layout: layout, route: route)
                .padding()
        }
    }
    
    func validateRoute() {
        let diag = LayoutDiagnostic(layout: layout)
        var errors = [DiagnosticError]()
        var resolverError = [GraphPathFinder.ResolverError]()
        diag.checkRoute(route: route, &errors, resolverErrors: &resolverError)
        if errors.isEmpty {
            routeError = .init(resolverErrors: resolverError, valid: true)
        } else {
            routeError = .init(resolverErrors: resolverError, valid: false)
        }
    }
}

struct RouteView_Previews: PreviewProvider {
    
    static let layout = LayoutLoop2().newLayout()
    
    static var previews: some View {
        RouteView(layout: layout, route: layout.routes[0])
    }
}
