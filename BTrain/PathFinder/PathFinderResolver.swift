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
        case emptyUnresolvedPath
        case emptyResolvedPaths
        case cannotResolveElement(at: Int)
        case cannotResolvePath(from: Int, to: Int)
    }
    
    /// Internal class that keeps track of all the elements of a path
    final class ResolvedPath {
        var path = [GraphPathElement]()
    }
    
    /// Internal class that keeps track of all the various possible paths.
    final class ResolvedPaths {
        var paths = [ResolvedPath]()

        func append(_ elements: [GraphPathElement]) {
            for element in elements {
                append(element)
            }
        }
        
        func append(_ element: GraphPathElement) {
            if paths.isEmpty {
                paths = [ResolvedPath()]
            }
            for path in paths {
                path.path.append(element)
            }
        }
        
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
        let result = try resolve(graph: graph,
                                 unresolvedPathIndex: 0,
                                 unresolvedPath: unresolvedPath,
                                 resolvedPath: GraphPath([]))
        return result
    }
    
    private func resolve(graph: Graph, unresolvedPathIndex: Int, unresolvedPath: [Resolvable], resolvedPath: GraphPath) throws -> Result<[GraphPath], ResolverError> {
        guard let unresolvedElement = unresolvedPath.first else {
            return .success([resolvedPath])
        }
        
        guard let resolvedElements = unresolvedElement.resolve(constraints) else {
            return .failure(.cannotResolveElement(at: unresolvedPathIndex))
        }

        var resolverError: ResolverError?
        var resolvedPaths = [GraphPath]()
        for resolvedElement in resolvedElements {
            let rp = ResolvedPath()
            rp.path = resolvedPath.elements
            if rp.path.isEmpty {
                rp.path.append(resolvedElement)
            }
            
            // Performance Optimization:
            // If both previousElement and to are separated only by turnouts,
            // we can more quickly find the missing turnouts by using the standard path finder
            // algorithm (instead of the shorted path algorithm which is going to analyze the entire
            // graph which takes time).
            else if fastResolve(graph: graph, resolvedPath: rp, to: resolvedElement) == false {
                // If the optimization above did not work, use the shortest path finder algorithm
                // to find the shortest path between the two elements without any restrictions (that is,
                // any number of turnouts and blocks can be situated in the path between the two elements).
                if try resolve(graph: graph, resolvedPath: rp, to: resolvedElement) == false {
                    resolverError = .cannotResolveElement(at: unresolvedPathIndex)
                    continue
                }
            }
            
            let result = try resolve(graph: graph,
                                     unresolvedPathIndex: unresolvedPathIndex + 1,
                                     unresolvedPath: Array(unresolvedPath.dropFirst()),
                                     resolvedPath: GraphPath(rp.path))
            switch result {
            case .success(let paths):
                for rp in paths {
                    resolvedPaths.append(rp)
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
            
    private func fastResolve(graph: Graph, resolvedPath: ResolvedPath, to: GraphPathElement) -> Bool {
        guard let previousElement = resolvedPath.path.last else {
            return true
        }
        
        let oc = lpf.constraints
        let pfc = PathFinder.Constraints(layout: oc.layout,
                                         train: oc.train,
                                         reservedBlockBehavior: oc.reservedBlockBehavior,
                                         stopAtFirstBlock: true,
                                         relaxed: oc.relaxed)
        let pf = PathFinder(constraints: pfc, settings: lpf.settings)
        if let p = pf.path(graph: graph, from: previousElement, to: to) {
            for resolvedElement in p.elements.dropFirst() {
                resolvedPath.path.append(resolvedElement)
            }
            return true
        } else {
            return false
        }
    }
    
    private func resolve(graph: Graph, resolvedPath: ResolvedPath, to: GraphPathElement) throws -> Bool {
        guard let previousElement = resolvedPath.path.last else {
            return true
        }
        if let p = try lpf.shortestPath(graph: graph, from: previousElement, to: to) {
            for resolvedElement in p.elements.dropFirst() {
                resolvedPath.path.append(resolvedElement)
            }
            return true
        } else {
            return false
        }
    }
}
