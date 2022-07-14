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

/// Defines the context when finding a path in a graph. Used by consumer of this class to provide user-defined context
/// for the appropriate situation (ie resolving a route, etc).
protocol GraphPathFinderContext {
    
}

// Defines the constraints when finding a path in a graph.
protocol GraphPathFinderConstraints {
    
    // Returns true if the specified node should be included in the path.
    // If false, the algorithm backtracks to the previous node and finds
    // an alternative edge if possible.
    func shouldInclude(node: GraphNode, currentPath: GraphPath, to: GraphPathElement?, context: GraphPathFinderContext) -> Bool
    
    // Returns true if the specified node is the destination node of the path.
    func reachedDestination(node: GraphNode, to: GraphPathElement?) -> Bool

}

// Defines the methods of a generic path finder in a graph.
protocol GraphPathFinding {
    
    // Returns the path between the specified `from` and `to` nodes, given the specified constraints.
    func path(graph: Graph, from: GraphNode, to: GraphNode?, constraints: GraphPathFinderConstraints, context: GraphPathFinderContext) -> GraphPath?
    
    // Returns the path between the specified `from` and `to` nodes, given the specified constraints.
    func path(graph: Graph, from: GraphPathElement, to: GraphPathElement?, constraints: GraphPathFinderConstraints, context: GraphPathFinderContext) -> GraphPath?

    // Returns the shortest path between the specified `from` and `to` nodes, given the specified constraints.
    func shortestPath(graph: Graph, from: GraphPathElement, to: GraphPathElement, constraints: GraphPathFinderConstraints, context: GraphPathFinderContext) throws -> GraphPath?

}

// Generic implementation that finds a path between two nodes of a graph.
struct GraphPathFinder: GraphPathFinding {
            
    struct Settings {
        // If true, emits debug logs to help troubleshoot the algorithm
        let verbose: Bool
        
        // If true, edges out of a node are chosen at random
        let random: Bool
        
        // Maximum number of elements in a path before giving up.
        // This value should be at least the number of nodes in the graph.
        let overflow: Int
    }
    
    let settings: Settings
    
    init(settings: Settings) {
        self.settings = settings
    }
    
    /// The default constraints for the graph
    final class DefaultConstraints: GraphPathFinderConstraints {
        
        func shouldInclude(node: GraphNode, currentPath: GraphPath, to: GraphPathElement?, context: GraphPathFinderContext) -> Bool {
            true
        }
        
        func reachedDestination(node: GraphNode, to: GraphPathElement?) -> Bool {
            false
        }

    }

    struct DefaultContext: GraphPathFinderContext {
        
    }
    
    /// Returns the shortest path between two nodes.
    func shortestPath(graph: Graph, from: GraphPathElement, to: GraphPathElement, constraints: GraphPathFinderConstraints = DefaultConstraints(), context: GraphPathFinderContext) throws -> GraphPath? {
        try GraphShortestPathFinder.shortestPath(graph: graph, from: from, to: to, constraints: constraints, context: context, verbose: settings.verbose)
    }
    
    /// Returns a path between two nodes.
    func path(graph: Graph, from: GraphNode, to: GraphNode?, constraints: GraphPathFinderConstraints = DefaultConstraints(), context: GraphPathFinderContext = DefaultContext()) -> GraphPath? {
        for socketId in shuffled(from.sockets(constraints)) {
            if let to = to {
                for toSocketId in shuffled(to.sockets(constraints)) {
                    if let steps = path(graph: graph, from: .starting(from, socketId), to: .ending(to, toSocketId), currentPath: GraphPath([.starting(from, socketId)]), constraints: constraints, context: context) {
                        return steps
                    }
                }
            } else {
                if let steps = path(graph: graph, from: .starting(from, socketId), to: nil, currentPath: GraphPath([.starting(from, socketId)]), constraints: constraints, context: context) {
                    return steps
                }
            }
        }
        return nil
    }

    /// Returns a path between two nodes.
    func path(graph: Graph, from: GraphPathElement, to: GraphPathElement?, constraints: GraphPathFinderConstraints = DefaultConstraints(), context: GraphPathFinderContext = DefaultContext()) -> GraphPath? {
        path(graph: graph, from: from, to: to, currentPath: GraphPath([from]), constraints: constraints, context: context)
    }
    
    /// Error from the path resolver indicating between which path elements an error occurred
    struct ResolverError {
        let from: Int
        let to: Int
    }
        
    final class ResolvedPath {
        var path = [GraphPathElement]()
    }
    
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
    func resolve(graph: Graph, _ unresolvedPath: UnresolvedGraphPath, constraints: GraphPathFinderConstraints = DefaultConstraints(), context: GraphPathFinderContext = DefaultContext(), errors: inout [ResolverError]) -> GraphPath? {
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
                debug("Unable to resolve path between \(previousElements) and \(resolvedElements)")
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
        if let p = self.path(graph: graph, from: previousElement, to: to, constraints: constraints, context: context) {
            for resolvedElement in p.elements.dropFirst() {
                resolvedPath.path.append(resolvedElement)
            }
            return true
        } else {
            return false
        }
    }

    private func path(graph: Graph, from: GraphPathElement, to: GraphPathElement?, currentPath: GraphPath, constraints: GraphPathFinderConstraints, context: GraphPathFinderContext) -> GraphPath? {
        if settings.verbose {
            if let to = to {
                debug("From \(from) to \(to): \(currentPath.toStrings)")
            } else {
                debug("From \(from): \(currentPath.toStrings)")
            }
        }
        
        guard currentPath.count < settings.overflow else {
            if settings.verbose {
                debug("Current path is overflowing, backtracking")
            }
            return nil
        }
        
        guard from != to else {
            return currentPath
        }
        
        guard let exitSocket = from.exitSocket else {
            if settings.verbose {
                debug("No exit socket defined for \(from.node)")
            }
            return nil
        }
        
        guard let edge = graph.edge(from: from.node, socketId: exitSocket, constraints: constraints) else {
            if settings.verbose {
                debug("No edge found from \(from.node) and socket \(exitSocket)")
            }
            return nil
        }
        
        guard let node = graph.node(for: edge.toNode, constraints: constraints) else {
            if settings.verbose {
                debug("No destination node found in graph for \(edge.toNode)")
            }
            return nil
        }
        
        guard let entrySocketId = edge.toNodeSocket else {
            if settings.verbose {
                debug("No entry socket for destination node \(node) in graph")
            }
            return nil
        }
                        
        if !constraints.shouldInclude(node: node, currentPath: currentPath, to: to, context: context) {
            debug("Node \(node) should not be included, backtracking")
            return nil
        }
                
        let endingElement = GraphPathElement.ending(node, entrySocketId)

        if let to = to, to.isSame(as: endingElement) {
            // If the destination node is specified and is the same as the current element,
            // we have reached the destination node
            return currentPath.appending(endingElement)
        } else if constraints.reachedDestination(node: node, to: to) {
            return currentPath.appending(endingElement)
        }

        // We haven't reached the destination node, keep going forward
        // by exploring all the possible exit sockets from `node`
        let exitSockets = node.reachableSockets(from: entrySocketId, constraints)
        for exitSocket in shuffled(exitSockets) {
            let betweenElement = GraphPathElement.between(node, entrySocketId, exitSocket)
            
            guard !currentPath.contains(betweenElement) else {
                if settings.verbose {
                    debug("Node \(betweenElement) is already part of the path, backtracking")
                }
                // Continue to the next socket as this socket (in combination with the entrySocketId)
                // has already been used in the path
                continue
            }
            
            if let path = path(graph: graph, from: betweenElement, to: to,
                               currentPath: currentPath.appending(.between(node, entrySocketId, exitSocket)),
                               constraints: constraints, context: context) {
                return path
            }
        }

        return nil
    }

    private func shuffled(_ sockets: [SocketId]) -> [SocketId] {
        if settings.random {
            return sockets.shuffled()
        } else {
            return sockets
        }
    }
    
    private func debug(_ msg: String) {
        if settings.verbose {
            BTLogger.debug(msg)
        }
    }
}
