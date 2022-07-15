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

/// Generic implementation that finds a path between two nodes of a graph.
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
    
    /// The default context which is simply empty
    struct DefaultContext: GraphPathFinderContext {
        
    }
    
    func shortestPath(graph: Graph, from: GraphPathElement, to: GraphPathElement, constraints: GraphPathFinderConstraints = DefaultConstraints(), context: GraphPathFinderContext) throws -> GraphPath? {
        try GraphShortestPathFinder.shortestPath(graph: graph, from: from, to: to, constraints: constraints, context: context, verbose: settings.verbose)
    }
    
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

    func path(graph: Graph, from: GraphPathElement, to: GraphPathElement?, constraints: GraphPathFinderConstraints = DefaultConstraints(), context: GraphPathFinderContext = DefaultContext()) -> GraphPath? {
        path(graph: graph, from: from, to: to, currentPath: GraphPath([from]), constraints: constraints, context: context)
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

    private func debug(_ msg: String) {
        if settings.verbose {
            BTLogger.debug(msg)
        }
    }
    
    private func shuffled(_ sockets: [SocketId]) -> [SocketId] {
        if settings.random {
            return sockets.shuffled()
        } else {
            return sockets
        }
    }
    
}
