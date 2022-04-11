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

// Defines the constraints when finding a path in a graph.
protocol GraphPathFinderConstraints {
    
    // Returns true if the specified node should be included in the path.
    // If false, the algorithm backtracks to the previous node and finds
    // an alternative edge if possible.
    func shouldInclude(node: GraphNode, currentPath: GraphPath, to: GraphPathElement?) -> Bool
    
    // Returns true if the specified node is the destination node of the path.
    func reachedDestination(node: GraphNode, to: GraphPathElement?) -> Bool

}

// Defines the methods of a generic path finder in a graph.
protocol GraphPathFinding {
    
    // Returns the path between the specified `from` and `to` nodes, given the specified constraints.
    func path(graph: Graph, from: GraphNode, to: GraphNode?, constraints: GraphPathFinderConstraints) -> GraphPath?
    
    // Returns the path between the specified `from` and `to` nodes, given the specified constraints.
    func path(graph: Graph, from: GraphPathElement, to: GraphPathElement?, constraints: GraphPathFinderConstraints) -> GraphPath?
    
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
        
        func shouldInclude(node: GraphNode, currentPath: GraphPath, to: GraphPathElement?) -> Bool {
            return true
        }
        
        func reachedDestination(node: GraphNode, to: GraphPathElement?) -> Bool {
            return false
        }

    }

    
    /// Returns the pseudo-shortest path between two nodes.
    func shortestPath(graph: Graph, from: GraphNode, to: GraphNode?, constraints: GraphPathFinderConstraints = DefaultConstraints()) -> GraphPath? {
        return shortestPath {
            path(graph: graph, from: from, to: to, constraints: constraints)
        }
    }
    
    /// Returns the pseudo-shortest path between two nodes.
    func shortestPath(graph: Graph, from: GraphPathElement, to: GraphPathElement?, constraints: GraphPathFinderConstraints = DefaultConstraints()) -> GraphPath? {
        return shortestPath {
            path(graph: graph, from: from, to: to, constraints: constraints)
        }
    }
    
    /// Returns a path between two nodes.
    func path(graph: Graph, from: GraphNode, to: GraphNode?, constraints: GraphPathFinderConstraints = DefaultConstraints()) -> GraphPath? {
        for socketId in shuffled(from.sockets) {
            if let to = to {
                for toSocketId in shuffled(to.sockets) {
                    if let steps = path(graph: graph, from: .starting(from, socketId), to: .ending(to, toSocketId), currentPath: GraphPath([.starting(from, socketId)]), constraints: constraints) {
                        return steps
                    }
                }
            } else {
                if let steps = path(graph: graph, from: .starting(from, socketId), to: nil, currentPath: GraphPath([.starting(from, socketId)]), constraints: constraints) {
                    return steps
                }
            }
        }
        return nil
    }

    /// Returns a path between two nodes.
    func path(graph: Graph, from: GraphPathElement, to: GraphPathElement?, constraints: GraphPathFinderConstraints = DefaultConstraints()) -> GraphPath? {
        return path(graph: graph, from: from, to: to, currentPath: GraphPath([from]), constraints: constraints)
    }
    
    /// Returns a resolved path given a path and the specified constraints.
    func resolve(graph: Graph, _ path: GraphPath, constraints: GraphPathFinderConstraints = DefaultConstraints()) -> GraphPath? {
        var resolvedPath = [GraphPathElement]()
        guard var previousElement = path.elements.first else {
            return nil
        }
        resolvedPath.append(previousElement)
        for element in path.elements.dropFirst() {
            if let p = self.path(graph: graph, from: previousElement, to: element, constraints: constraints) {
                for resolvedElement in p.elements.dropFirst() {
                    resolvedPath.append(resolvedElement)
                }
            } else {
                // A path should always be resolvable between two elements. If not, it means
                // that some constraints imposed by a subclass prevents a path from being found
                // so we always return here instead of continuing and returning an incomplete route.
                return nil
            }
            previousElement = element
        }
        return GraphPath(resolvedPath)
    }

    /// Note: until we have a proper algorithm that finds the shortest path in a single pass,
    /// we will generate a few paths and pick the shortest one.
    private func shortestPath(pathGenerator: () -> GraphPath?) -> GraphPath? {
        let numberOfPaths = 10
        var smallestPath: GraphPath?
        for _ in 1...numberOfPaths {
            if let path = pathGenerator() {
                if smallestPath == nil {
                    smallestPath = path
                } else if let sp = smallestPath, path.count < sp.count {
                    smallestPath = path
                }
            }
        }
        return smallestPath
    }
    
    private func path(graph: Graph, from: GraphPathElement, to: GraphPathElement?, currentPath: GraphPath, constraints: GraphPathFinderConstraints = DefaultConstraints()) -> GraphPath? {
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
        
        guard let edge = graph.edge(from: from.node, socketId: exitSocket) else {
            if settings.verbose {
                debug("No edge found from \(from.node) and socket \(exitSocket)")
            }
            return nil
        }
        
        guard let node = graph.node(for: edge.toNode) else {
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
                
        let endingElement = GraphPathElement.ending(node, entrySocketId)
        
        if !constraints.shouldInclude(node: node, currentPath: currentPath, to: to) {
            debug("Node \(node) should not be included, backtracking")
            return nil
        }
                
        if let to = to, to.isSame(as: endingElement) {
            // If the destination node is specified and is the same as the current element,
            // we have reached the destination node
            return currentPath.appending(endingElement)
        } else if constraints.reachedDestination(node: node, to: to) {
            return currentPath.appending(endingElement)
        }

        // We haven't reached the destination node, keep going forward
        // by exploring all the possible exit sockets from `node`
        let exitSockets = node.reachableSockets(from: entrySocketId)
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
                               constraints: constraints) {
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
