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

    @State private var showResultsSummary = false

    @State private var commandErrorIds = [String]()
    
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
            return layout.routeDescription(for: nil, steps: generatedRoute.partialSteps)
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
    
    var errorSummary: String? {
        if let error = generatedRouteError {
            return error.localizedDescription
        } else if case .failure(let error) = resolvedRouteResult {
            return error.localizedDescription
        } else {
            return nil
        }
    }
        
    var body: some View {
        VStack {
            if script.commands.isEmpty {
                CenteredCustomView {
                    Text("No Commands")
                    Button("+") {
                        script.commands.append(ScriptCommand(action: .move))
                    }
                }
            } else {
                List {
                    ForEach($script.commands, id: \.self) { command in
                        ScriptLineView(layout: layout, script: script, command: command, commandErrorIds: $commandErrorIds)
                        if let children = command.children {
                            ForEach(children, id: \.self) { command in
                                HStack {
                                    Spacer().fixedSpace()
                                    ScriptLineView(layout: layout, script: script, command: command, commandErrorIds: $commandErrorIds)
                                }
                            }
                        }
                    }
                }
                HStack {
                    Button("Verify") {
                        validate(script: script)
                    }
                    switch verifyStatus {
                    case .none:
                        Spacer()
                        
                    case .failure:
                        Text("􀇾")
                        if let errorSummary = errorSummary {
                            Text(errorSummary)
                        }
                        Spacer()
                        
                    case .success:
                        Text("􀁢")
                        
                        Spacer()
                        
                        Button("View Resulting Route") {
                            showResultsSummary.toggle()
                        }
                        .sheet(isPresented: $showResultsSummary, content: {
                            AlertCustomView {
                                VStack(alignment: .leading) {
                                    VStack(alignment: .leading) {
                                        Text("Generated Route:")
                                            .font(.title2)
                                        ScrollView {
                                            Text("\(generatedRouteDescription)")
                                        }.frame(minHeight: 80)
                                    }
                                    VStack(alignment: .leading) {
                                        Text("Resolved Route:")
                                            .font(.title2)
                                        ScrollView {
                                            Text("\(resolvedRouteDescription)")
                                        }.frame(minHeight: 80)
                                    }
                                }
                                .padding()
                                .frame(maxWidth: 600)
                            }
                        })
                    }
                }.padding([.leading, .trailing])
            }
        }
    }
    
    func validate(script: Script) {
        resolvedRouteResult = nil
        generatedRouteError = nil
        commandErrorIds.removeAll()
        
        do {
            generatedRoute = try script.toRoute()
        } catch let error as ScriptError {
            generatedRouteError = error
            switch error {
            case .undefinedBlock(let command):
                commandErrorIds.append(command.id.uuidString)

            case .undefinedDirection(command: let command):
                commandErrorIds.append(command.id.uuidString)

            case .undefinedStation(let command):
                commandErrorIds.append(command.id.uuidString)
                
            case .missingStartCommand:
                script.commands.insert(ScriptCommand(action: .start), at: 0)
            }
            return
        } catch {
            generatedRouteError = error
            return
        }

        guard let generatedRoute = generatedRoute else {
            return
        }
        
        // TODO: simplify this whole thing
        let diag = LayoutDiagnostic(layout: layout)
        var errors = [LayoutDiagnostic.DiagnosticError]()
        var resolverError = [PathFinderResolver.ResolverError]()
        var resolvedRoutes = RouteResolver.ResolvedRoutes()
        diag.checkRoute(route: generatedRoute, &errors, resolverErrors: &resolverError, resolverPaths: &resolvedRoutes)
        if let resolverError = resolverError.first {
            switch resolverError {
            case .cannotResolvedSegment(_, let from, let to):
                if let id = from.sourceIdentifier {
                    commandErrorIds.append(id)
                }
                if let id = to.sourceIdentifier {
                    commandErrorIds.append(id)
                }
            default:
                break
            }
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
        Group {
            ScriptView(layout: layout, script: layout.scripts[0])
        }.previewDisplayName("Script")
        Group {
            ScriptView(layout: layout, script: Script())
        }.previewDisplayName("Empty Script")
    }
}
