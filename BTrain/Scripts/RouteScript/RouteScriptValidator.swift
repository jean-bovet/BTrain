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

import Foundation

struct RouteScriptValidator {
    
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
        
    private var generatedRoute: Route?
    private var generatedRouteError: Error?
  
    private var resolvedRouteResult: Result<[ResolvedRouteItem]?, Error>?

    var commandErrorIds = [String]()
        
    func generatedRouteDescription(layout: Layout) -> String {
        if let error = generatedRouteError {
            return error.localizedDescription
        } else if let generatedRoute = generatedRoute {
            return layout.routeDescription(for: nil, steps: generatedRoute.partialSteps)
        } else {
            return ""
        }
    }
        
    mutating func validate(script: RouteScript, layout: Layout) {
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
                script.commands.insert(RouteScriptCommand(action: .start), at: 0)
            }
            return
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
