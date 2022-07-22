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

// A route consists of one or more steps. Each step defines a turnout or a block that the train needs to follow.
// The steps of a route do not necessarily contain contiguous turnout or block. For example, the user can create a route
// with just a few blocks specified and it will be up to this class to find out the missing turnouts (and blocks) to
// create a contiguous route.
// Note: at the moment, only missing turnouts will be handled but in a future release, missing blocks will be supported as well.
final class RouteResolver {
    let layout: Layout
    let train: Train
    
    init(layout: Layout, train: Train) {
        self.layout = layout
        self.train = train
    }
    
    // This function takes an array of steps and returns a resolved array of steps. The returned array
    // contains all the blocks and turnouts that were not explicitly indicated in the first array.
    // Note: a train must be specified in order to resolve the steps because a train can have specific requirements
    // to avoid certain blocks or turnouts, in addition to the algorithm checking allowing block (or turnout)
    // already reserved for the same train to be accepted as resolved steps.
    // Returns nil if the route cannot be resolved. This can happen, for example, if a turnout or block is already
    // reserved for another train and no other alternative path is found.
    func resolve(steps: ArraySlice<RouteItem>,
                 errors: inout [GraphPathFinderResolver.ResolverError],
                 verbose: Bool = SettingsKeys.bool(forKey: SettingsKeys.logRoutingResolutionSteps)) throws -> [ResolvedRouteItem]? {
        let settings = LayoutPathFinder.Settings(verbose: verbose,
                                                    random: false,
                                                    overflow: layout.pathFinderOverflowLimit)
        // Note: avoid all reserved block when resolving to ensure maximum constraints.
        // If that fails, the algorithm will retry without constraints.
        let pf = LayoutPathFinder(layout: layout, train: train, reservedBlockBehavior: .avoidReserved, settings: settings)
                
        // Create the unresolved path out of the route steps
        let unresolvedPath: UnresolvedGraphPath = steps.map { $0 }

        // Try to resolve the route using the standard constraints (which are a super set of the constraints
        // when finding a new route, which provides consistent behavior when resolving a route).
        if let resolvedPath = pf.resolve(graph: layout, unresolvedPath, constraints: ResolverConstraints(layoutConstraints: pf.constraints), context: pf.context, errors: &errors) {
            return resolvedPath.elements.toResolvedRouteItems
        }
        
        // If we are not able to resolve the route using the standard constraints, it means there are no path available
        // that satisfies the constraints; for example, a fixed route has a disable block that makes it impossible to resolve.
        // Let's try again to resolve the route using the basic constraints at the graph-level - this means, all layout-specific
        // constraints (such as block reserved, disabled, etc) are ignored.
        let relaxedContext = LayoutPathFinder.LayoutContext(layout: layout, train: train, reservedBlockBehavior: .ignoreReserved)
        errors.removeAll()
        if let resolvedPath = pf.resolve(graph: layout, unresolvedPath, constraints: ResolverConstraints(layoutConstraints: LayoutPathFinder.DefaultConstraints()), context: relaxedContext, errors: &errors) {
            return resolvedPath.elements.toResolvedRouteItems
        }

        // If we reach that point, it means the graph itself has a problem with its node and edges and no path can be found.
        return nil
    }
    
    final class ResolverConstraints: GraphPathFinderConstraints {
        
        let delegatedConstraints: GraphPathFinderConstraints
        
        init(layoutConstraints: GraphPathFinderConstraints) {
            self.delegatedConstraints = layoutConstraints
        }
        
        func reachedDestination(node: GraphNode, to: GraphPathElement?) -> Bool {
            delegatedConstraints.reachedDestination(node: node, to: to)
        }
        
        func shouldInclude(node: GraphNode, currentPath: GraphPath, to: GraphPathElement?, context: GraphPathFinderContext) -> Bool {
            guard let to = to else {
                return delegatedConstraints.shouldInclude(node: node, currentPath: currentPath, to: to, context: context)
            }
            
            if node is Block && to.node is Block && node.identifier.uuid != to.node.identifier.uuid {
                // Backtrack if the first block is not the destination node.
                // Note: this is currently a limitation of the resolver in which it is expected that a route
                // defines all the blocks in the route. The resolver just resolves the turnouts between two
                // blocks but not an arbitrary long route with turnouts and blocks, which can be expensive
                // to traverse until we have a breadth-first algorithm implementation to search for the shortest
                // path between one block to another (arbitrary far away) block.
                return false
            }
            
            return delegatedConstraints.shouldInclude(node: node, currentPath: currentPath, to: to, context: context)
        }
    }
}
