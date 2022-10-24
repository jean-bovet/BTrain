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

struct RouteValidationView: View {
    
    struct RouteError {
        let resolverErrors: [PathFinderResolver.ResolverError]
        let valid: Bool
    }
    
    let layout: Layout
    let route: Route
    
    @Binding var routeError: RouteError?
    @State private var resolvedRouteItems: [ResolvedRouteItem]?
    
    var resolvedRouteDescription: String {
        guard let resolvedRouteItems = resolvedRouteItems else {
            return ""
        }
        
        return resolvedRouteItems.toBlockNames().joined(separator: "→")
    }
    
    var body: some View {
        VStack(alignment: .leading) {
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
            if let routeError = routeError, routeError.valid {
                Text("\(resolvedRouteDescription)")
            }
        }
    }
    
    func validateRoute() {
        let diag = LayoutDiagnostic(layout: layout)
        var errors = [LayoutDiagnostic.DiagnosticError]()
        var resolverError = [PathFinderResolver.ResolverError]()
        var resolvedRoutes = RouteResolver.ResolvedRoutes()
        diag.checkRoute(route: route, &errors, resolverErrors: &resolverError, resolverPaths: &resolvedRoutes)
        if errors.isEmpty {
            resolvedRouteItems = resolvedRoutes.first
            routeError = .init(resolverErrors: resolverError, valid: true)
        } else {
            routeError = .init(resolverErrors: resolverError, valid: false)
        }
    }

}

extension Array where Element == ResolvedRouteItem {
    
    func toBlockNames() -> [String] {
        self.compactMap { step in
            switch step {
            case .block(let stepBlock):
                return stepBlock.block.name
            case .turnout(_):
                return nil
            }
        }
    }

}

struct RouteValidationView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutComplexLoop().newLayout())
    
    static var previews: some View {
        RouteValidationView(layout: doc.layout, route: doc.layout.routes[0], routeError: .constant(nil))
    }
}
