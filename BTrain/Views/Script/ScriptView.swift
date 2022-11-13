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

struct ScriptView: View {
    
    struct ValidationError {
        let resolverErrors: [PathFinderResolver.ResolverError]
        let valid: Bool
    }

    let layout: Layout
    @ObservedObject var script: Script
    
    @State private var scriptToRouteError: Error?
    @State private var scriptValidationError: ValidationError?
    @State private var resolvedRouteItems: [ResolvedRouteItem]?

    var verifyDescription: String {
        if let error = scriptToRouteError {
            return error.localizedDescription
        }
        
        if let routeError = scriptValidationError {
            if routeError.valid {
                return resolvedRouteItems?.toBlockNames().joined(separator: "→") ?? "?"
            } else {
                return routeError.resolverErrors.first?.localizedDescription ?? ""
            }
        } else {
            return ""
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                List {
                    ForEach($script.commands, id: \.self) { command in
                        ScriptLineView(layout: layout, commands: $script.commands, command: command)
                        if let children = command.children {
                            ForEach(children, id: \.self) { command in
                                HStack {
                                    Spacer().fixedSpace()
                                    ScriptLineView(layout: layout, commands: $script.commands, command: command)
                                }
                            }
                        }
                    }
                }
                VStack(alignment: .leading) {
                    HStack {
                        Button("Verify") {
                            validate(script: script)
                        }
                        if let routeError = scriptValidationError {
                            if routeError.valid {
                                Text("􀁢")
                            } else {
                                Text("􀇾")
                            }
                        }
                        Spacer()
                    }
                    Text(verifyDescription)
                    Spacer()
                }.padding()
            }

            HStack {
                Text("\(script.commands.count) commands")
                Spacer()
                Button("+") {
                    script.commands.append(ScriptCommand(action: .move))
                }
                Button("-") {
                    
                }
            }.padding()
        }
    }
    
    func validate(script: Script) {
        let route: Route
        do {
            route = try script.toRoute()
        } catch {
            scriptToRouteError = error
            return
        }

        let diag = LayoutDiagnostic(layout: layout)
        var errors = [LayoutDiagnostic.DiagnosticError]()
        var resolverError = [PathFinderResolver.ResolverError]()
        var resolvedRoutes = RouteResolver.ResolvedRoutes()
        diag.checkRoute(route: route, &errors, resolverErrors: &resolverError, resolverPaths: &resolvedRoutes)
        if errors.isEmpty {
            resolvedRouteItems = resolvedRoutes.first
            scriptValidationError = .init(resolverErrors: resolverError, valid: true)
        } else {
            scriptValidationError = .init(resolverErrors: resolverError, valid: false)
        }
    }
    
}

struct ScriptView_Previews: PreviewProvider {
        
    static let layout = {
        let layout = Layout()
        let s = Script(name: "Boucle")
        s.commands.append(ScriptCommand(action: .move))
        var loop = ScriptCommand(action: .loop)
        loop.repeatCount = 2
        loop.children.append(ScriptCommand(action: .move))
        loop.children.append(ScriptCommand(action: .move))
        s.commands.append(loop)
        layout.scriptMap[s.id] = s
        return layout
    }()

    static var previews: some View {
        ScriptView(layout: layout, script: layout.scripts[0])
    }
}
