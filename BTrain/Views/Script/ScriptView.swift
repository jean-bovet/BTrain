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
    
    @State private var generatedRoute: Route?
    @State private var generatedRouteError: Error?
  
    @State private var resolvedRouteResult: Result<[ResolvedRouteItem]?, Error>?

    @State private var routeExpanded = false
    @State private var resolvedRouteExpanded = false

    enum VerifyStatus {
        case none
        case failure
        case success
    }
    
    var verifyStatus: VerifyStatus {
        if generatedRouteError != nil {
            return .failure
        }
        
        switch resolvedRouteResult {
        case .success:
            return .success
        case .failure:
            return .failure
        case .none:
            return .none
        }
    }
    
    var generatedRouteDescription: String {
        if let error = generatedRouteError {
            return error.localizedDescription
        } else if let generatedRoute = generatedRoute {
            return layout.routeDescription(for: nil, steps: generatedRoute.steps)
        } else {
            return ""
        }
    }
        
    var resolvedRouteDescription: String {
        guard let resolvedRouteResult = resolvedRouteResult else {
            return ""
        }
        switch resolvedRouteResult {
        case .failure(let error):
            return error.localizedDescription
        case .success(let resolvedRouteItems):
            return resolvedRouteItems?.toBlockNames().joined(separator: "→") ?? "Empty Route"
        }
    }
    
    var body: some View {
        VStack {
            List {
                ForEach($script.commands, id: \.self) { command in
                    ScriptLineView(layout: layout, script: script, command: command)
                    if let children = command.children {
                        ForEach(children, id: \.self) { command in
                            HStack {
                                Spacer().fixedSpace()
                                ScriptLineView(layout: layout, script: script, command: command)
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
                    switch verifyStatus {
                    case .none:
                        Text("")
                    case .failure:
                        Text("􀇾")
                    case .success:
                        Text("􀁢")
                    }
                    Spacer()
                }

                ScrollView {
                    DisclosureGroup("Generated Route") {
                        Text(generatedRouteDescription)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    DisclosureGroup("Resolved Route") {
                        Text(resolvedRouteDescription)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.frame(maxHeight: 200)
            }.padding()
        }
    }
    
    func validate(script: Script) {
        resolvedRouteResult = nil
        generatedRouteError = nil
        
        do {
            generatedRoute = try script.toRoute()
        } catch {
            generatedRouteError = error
            return
        }

        guard let generatedRoute = generatedRoute else {
            return
        }
        
        let diag = LayoutDiagnostic(layout: layout)
        var errors = [LayoutDiagnostic.DiagnosticError]()
        var resolverError = [PathFinderResolver.ResolverError]()
        var resolvedRoutes = RouteResolver.ResolvedRoutes()
        diag.checkRoute(route: generatedRoute, &errors, resolverErrors: &resolverError, resolverPaths: &resolvedRoutes)
        if let resolverError = resolverError.first {
            resolvedRouteResult = .failure(resolverError)
        } else {
            resolvedRouteResult = .success(resolvedRoutes.first)
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
