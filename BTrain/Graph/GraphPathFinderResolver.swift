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

/// This class implements the path resolving algorithm for a given graph.
///
/// It works by taking in an unresolved path, that is, a path with missing or unspecified
/// node that need to be filled to get a path with continuous nodes.
///
/// For example, a user can build a route with a starting and ending station and only one block,
/// leaving all the other blocks unspecified. The role of this algorithm is to find these unspecified blocks
struct GraphPathFinderResolver {
    
    /// A reference to the path finding algoritm
    let gpf: GraphPathFinding
    
    /// Error from the path resolver indicating between which path elements an error occurred
    struct ResolverError {
        let from: Int
        let to: Int
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
    /// In summary, the algorithm is to resolve the unresolved path by producing all the possible resolved paths and then
    /// select from the resolved paths the ones that are valid.
    ///
    /// - Parameters:
    ///   - graph: the graph in which the path is located
    ///   - unresolvedPath: the unresolved path
    ///   - constraints: the constraints to apply
    ///   - context: the context to use
    ///   - errors: any resolving errors
    /// - Returns: a resolved path
    func resolve(graph: Graph, _ unresolvedPath: UnresolvedGraphPath,
                 constraints: GraphPathFinderConstraints = GraphPathFinder.DefaultConstraints(),
                 context: GraphPathFinderContext = GraphPathFinder.DefaultContext(),
                 errors: inout [ResolverError]) -> GraphPath? {
        let resolvedPaths = ResolvedPaths()
        guard var previousElements = unresolvedPath.first?.resolve(constraints, context) else {
            return nil
        }
                
        var unresolvedPathIndex = 1
        resolvedPaths.append(previousElements)
        for unresolvedElement in unresolvedPath.dropFirst() {
            guard let resolvedElements = unresolvedElement.resolve(constraints, context) else {
                BTLogger.router.error("Unable to resolve element \(unresolvedElement.description, privacy: .public)")
                return nil
            }
            
            resolve(graph: graph, resolvedPaths: resolvedPaths, to: resolvedElements,
                    constraints: constraints, context: context)
            
            if resolvedPaths.paths.isEmpty {
                // There should always be at least one resolved path between two elements. If not, it means
                // that some constraints imposed by a subclass prevents a path from being found
                // so we always return here instead of continuing and returning an incomplete route.
                BTLogger.router.debug("Unable to resolve path between \(previousElements, privacy: .public) and \(resolvedElements, privacy: .public)")
                errors.append(ResolverError(from: unresolvedPathIndex - 1, to: unresolvedPathIndex))
                return nil
            }

            previousElements = resolvedElements
            unresolvedPathIndex += 1
        }
        
        if let resolvedPath = resolvedPaths.paths.first?.path {
            return GraphPath(resolvedPath)
        } else {
            return nil
        }
    }
    
    private func resolve(graph: Graph, resolvedPaths: ResolvedPaths, to resolvedElements: [GraphPathElement],
                         constraints: GraphPathFinderConstraints, context: GraphPathFinderContext) {
        for (index, resolvedPath) in resolvedPaths.paths.enumerated() {
            for resolvedElement in resolvedElements {
                if resolve(graph: graph, resolvedPath: resolvedPath, to: resolvedElement,
                           constraints: constraints, context: context) == false {
                    // Unable to resolve this path, so remove this path from the list of resolved paths
                    resolvedPaths.paths.remove(at: index)
                }
            }
        }
    }
    
    private func resolve(graph: Graph, resolvedPath: ResolvedPath, to: GraphPathElement,
                         constraints: GraphPathFinderConstraints, context: GraphPathFinderContext) -> Bool {
        guard let previousElement = resolvedPath.path.last else {
            return true
        }
        if let p = gpf.path(graph: graph, from: previousElement, to: to, constraints: constraints, context: context) {
            for resolvedElement in p.elements.dropFirst() {
                resolvedPath.path.append(resolvedElement)
            }
            return true
        } else {
            return false
        }
    }
}
