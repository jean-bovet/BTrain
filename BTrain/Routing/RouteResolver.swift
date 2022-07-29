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

/// This class resolves an arbitrary route by finding all the missing elements, turnouts or blocks, that are not explicitely specified in the route.
///
/// A route consists of one or more steps. Each step defines a turnout or a block that the train needs to follow. The steps of a route do not
/// necessarily contain contiguous turnout or block. For example, the user can create a route with just a few blocks specified and it will be up
/// to this class to find out the missing turnouts (and blocks) to create a contiguous route.
///
/// Note: a train must be specified in order to resolve the steps because a train can have specific requirements
/// to avoid certain blocks or turnouts, in addition to the algorithm checking allowing block (or turnout)
/// already reserved for the same train to be accepted as resolved steps.
final class RouteResolver {
    let layout: Layout
    let train: Train
    
    init(layout: Layout, train: Train) {
        self.layout = layout
        self.train = train
    }
     
    /// An array of resolved paths
    typealias ResolvedRoutes = [[ResolvedRouteItem]]
    
    /// Contains one or more resolved path or an error indicating why the path could not be resolved
    typealias ResolverResult = Result<ResolvedRoutes,PathFinderResolver.ResolverError>
    
    /// This function takes an array of steps and returns a resolved array of steps.
    ///
    /// - Parameters:
    ///   - steps: the unresolved steps
    ///   - verbose: true to enable debug output during resolution
    /// - Returns: the result of the resolving algorithm
    func resolve(unresolvedPath: [Resolvable],
                 verbose: Bool = SettingsKeys.bool(forKey: SettingsKeys.logRoutingResolutionSteps)) throws -> ResolverResult {
        let settings = PathFinder.Settings(verbose: verbose,
                                           random: false,
                                           overflow: layout.pathFinderOverflowLimit)
        
        let result = try resolve(unresolvedPath: unresolvedPath, settings: settings, relaxed: false)
        switch result {
        case .success(let resolvedPaths):
            return .success(resolvedPaths)
            
        case .failure(_):
            // If we are not able to resolve the route using the standard constraints, it means there are no path available
            // that satisfies the constraints; for example, a fixed route has a disabled block that makes it impossible to resolve.
            // Let's try again to resolve the route using the basic constraints at the graph-level - this means, all layout-specific
            // constraints (such as block reserved, disabled, etc) are ignored.
            return try resolve(unresolvedPath: unresolvedPath, settings: settings, relaxed: true)
        }
    }
    
    private func resolve(unresolvedPath: [Resolvable], settings: PathFinder.Settings, relaxed: Bool) throws -> ResolverResult {
        let constraints = PathFinder.Constraints(layout: layout,
                                                 train: train,
                                                 reservedBlockBehavior: relaxed ? .ignoreReserved : .avoidReserved,
                                                 stopAtFirstBlock: false,
                                                 relaxed: relaxed)
        let pf = PathFinder(constraints: constraints, settings: settings)
        let result = try pf.resolve(graph: layout, unresolvedPath)
        switch result {
        case .success(let resolvedPaths):
            return .success(resolvedPaths.map { $0.elements.toResolvedRouteItems })
            
        case .failure(let error):
            return .failure(error)
        }
    }
    
}
