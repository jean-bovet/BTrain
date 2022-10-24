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

/// Protocol describing an item that can be resolved to a single path element
protocol Resolvable: CustomStringConvertible {
    
    /// Resolves this object using the specified constraints
    /// - Parameter constraints: the constraints
    /// - Returns: a resolved path element or nil if it cannot be resolved
    func resolve(_ constraints: PathFinder.Constraints) -> [GraphPathElement]?

}

/// This class implements the path resolving algorithm for a given graph.
///
/// It works by taking in an unresolved path, that is, a path with missing or unspecified
/// node that need to be filled to get a path with continuous nodes.
///
/// For example, a user can build a route with a starting and ending station and only one block,
/// leaving all the other blocks unspecified. The role of this algorithm is to find these unspecified blocks
struct PathFinderResolver {
    
    /// A reference to the path finding algoritm
    let lpf: PathFinder
    
    /// The constraints
    let constraints: PathFinder.Constraints
    
    /// Error from the path resolver indicating between which path elements an error occurred
    enum ResolverError: Error {
        case cannotResolveElement(at: Int)
        case cannotResolvePath(from: Int, to: Int)
    }
        
    /// Returns a resolved path given an unresolved path and the specified constraints.
    ///
    /// For example:
    /// "Station A" > "Block D" > "Station B"
    /// can return one or more possible resolved paths, depending on the individual elements that get resolved.
    /// For example, Station A has two blocks, A1 and A2. A1 can be used in both direction, so both (A1,next) and (A1,previous)
    /// is returned. This leads to the following possibilities (only 2 are shown):
    /// - (A1,next) (D,next) (B1,next): this path is valid
    /// - (A1,previous) (D,next) (B1,next): this path is invalid because the train cannot go from (A1,previous) to (D,next)
    /// In summary, the algorithm resolves the unresolved path by producing all the possible resolved paths and then
    /// selecting from the resolved paths the ones that are valid.
    ///
    /// - Parameters:
    ///   - graph: the graph in which the path is located
    ///   - unresolvedPath: the unresolved path
    /// - Returns: the result of the resolving operation
    func resolve(graph: Graph, _ unresolvedPath: [Resolvable]) throws -> Result<[GraphPath], ResolverError> {
        let result = try resolveRecursively(graph: graph,
                                            unresolvedPathIndex: 0,
                                            unresolvedPath: unresolvedPath,
                                            resolvedPathSoFar: GraphPath([]))
        return result
    }
    
    private func resolveRecursively(graph: Graph, unresolvedPathIndex: Int, unresolvedPath: [Resolvable], resolvedPathSoFar: GraphPath) throws -> Result<[GraphPath], ResolverError> {
        guard let unresolvedElement = unresolvedPath.first else {
            return .success([resolvedPathSoFar])
        }
        
        // Resolve the first unresolved element of the unresolved path. Note that
        // there can be more than one resolved elements. For example, if a block step
        // does not have its direction specified, 2 resolved elements are returned,
        // one for each direction of the block.
        guard let resolvedElements = unresolvedElement.resolve(constraints) else {
            return .failure(.cannotResolveElement(at: unresolvedPathIndex))
        }

        // Contains the last error that occurred during the resolving process. Because more than
        // one error can happen in the tree of search, the last one is returned to the user.
        var resolverError: ResolverError?
        
        // An array of all possible resolved paths. Note that because each time an element is resolved
        // it can result in more than one resolved element, this means that there can be more than one
        // resolved path at the end of the search.
        var resolvedPaths = [GraphPath]()
        
        // For each resolved elements, resolve the segment between the previous element and this one,
        // then recursively continue the search for each resolved element.
        for resolvedElement in resolvedElements {
            // Resolve the segment between the last resolved path elements and the new resolved element.
            let result = try resolveSegment(graph: graph,
                                            unresolvedPathIndex: unresolvedPathIndex,
                                            from: resolvedPathSoFar.elements.last,
                                            to: resolvedElement)
            switch result {
            case .success(let resolvedSegment):
                // If the segment was resolved, recursively continue the resolving process
                // using the next unresolved path element and the resolved path found so far.
                let result = try resolveRecursively(graph: graph,
                                                    unresolvedPathIndex: unresolvedPathIndex + 1,
                                                    unresolvedPath: Array(unresolvedPath.dropFirst()),
                                                    resolvedPathSoFar: resolvedPathSoFar+resolvedSegment)
                switch result {
                case .success(let paths):
                    for rp in paths {
                        resolvedPaths.append(rp)
                    }
                case .failure(let error):
                    resolverError = error
                }
            case .failure(let error):
                resolverError = error
            }
        }
        
        if resolvedPaths.isEmpty {
            if let resolverError = resolverError {
                return .failure(resolverError)
            } else {
                return .failure(.cannotResolvePath(from: 0, to: unresolvedPathIndex))
            }
        } else {
            return .success(resolvedPaths)
        }
    }
            
    private func resolveSegment(graph: Graph, unresolvedPathIndex: Int, from: GraphPathElement?, to: GraphPathElement) throws -> Result<GraphPath,ResolverError> {
        guard let from = from else {
            return .success(GraphPath(to))
        }

        let p = try resolveSegment(graph: graph, from: from, to: to)
        if p.isEmpty {
            return .failure(.cannotResolveElement(at: unresolvedPathIndex))
        } else {
            return .success(p)
        }
    }
    
    private func resolveSegment(graph: Graph, from: GraphPathElement, to: GraphPathElement) throws -> GraphPath {
        // Performance Optimization:
        // If both `from` and `to` are separated only by turnouts,
        // we can more quickly find the missing turnouts by using the standard path finder
        // algorithm (instead of the shorted path algorithm which is going to analyze the entire
        // graph which takes time).
        var path = fastResolve(graph: graph, from: from, to: to)
        if path.isEmpty {
            // If the optimization above did not work, use the shortest path finder algorithm
            // to find the shortest path between the two elements without any restrictions (that is,
            // any number of turnouts and blocks can be situated in the path between the two elements).
            path = try resolve(graph: graph, from: from, to: to)
        }
        return path
    }
    
    private func fastResolve(graph: Graph, from: GraphPathElement, to: GraphPathElement) -> GraphPath {
        let oc = lpf.constraints
        let pfc = PathFinder.Constraints(layout: oc.layout,
                                         train: oc.train,
                                         reservedBlockBehavior: oc.reservedBlockBehavior,
                                         stopAtFirstBlock: true,
                                         relaxed: oc.relaxed)
        let pf = PathFinder(constraints: pfc, settings: lpf.settings)
        if let p = pf.path(graph: graph, from: from, to: to) {
            return GraphPath(p.elements.dropFirst())
        } else {
            return GraphPath.empty()
        }
    }
    
    private func resolve(graph: Graph, from: GraphPathElement, to: GraphPathElement) throws -> GraphPath {
        if let p = try lpf.shortestPath(graph: graph, from: from, to: to) {
            return GraphPath(p.elements.dropFirst())
        } else {
            return GraphPath.empty()
        }
    }
}
