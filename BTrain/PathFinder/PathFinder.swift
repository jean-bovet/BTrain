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

// This class finds path from one block to another in the layout, taking
// into consideration various constraints, such as disabled block, reserved blocks, etc.
struct PathFinder {
    let constraints: Constraints

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

    /// Returns the path between two nodes in a graph, given the specified constraints and context.
    ///
    /// - Parameters:
    ///   - graph: the graph
    ///   - from: the starting node
    ///   - to: the destination node or nil to find the next destination block (as defined by ``LayoutPathFinder.LayoutConstraints/reachedDestination(node:to:)``
    /// - Returns: a path or nil if no path is found
    func path(graph: Graph, from: GraphNode, to: GraphNode?) -> GraphPath? {
        for socketId in shuffled(from.sockets()) {
            if let to = to {
                for toSocketId in shuffled(to.sockets()) {
                    if let steps = path(graph: graph, from: .starting(from, socketId), to: .ending(to, toSocketId), currentPath: GraphPath([.starting(from, socketId)])) {
                        return steps
                    }
                }
            } else {
                if let steps = path(graph: graph, from: .starting(from, socketId), to: nil, currentPath: GraphPath([.starting(from, socketId)])) {
                    return steps
                }
            }
        }
        return nil
    }

    /// Returns the path between two path elements in a graph, given the specified constraints and context.
    ///
    /// A path element is a node with a specific entry and exit socket defined.
    ///
    /// - Parameters:
    ///   - graph: the graph
    ///   - from: the starting element
    ///   - to: the destination element or nil to find the next destination block (as defined by ``LayoutPathFinder.LayoutConstraints/reachedDestination(node:to:)``
    /// - Returns: a path or nil if no path is found
    func path(graph: Graph, from: GraphPathElement, to: GraphPathElement?) -> GraphPath? {
        path(graph: graph, from: from, to: to, currentPath: GraphPath([from]))
    }

    /// Resolves an unresolved path by making sure each element is resolved. For example, a station is unresolved
    /// because it contains one or more blocks: it gets resolved by selecting a particular block given the constraints.
    ///
    /// - Parameters:
    ///   - graph: the graph
    ///   - path: the unresolved path
    /// - Returns: the result of the resolver
    func resolve(graph: Graph, _ path: [Resolvable]) throws -> Result<[GraphPath], PathFinderResolver.ResolverError> {
        let resolver = PathFinderResolver(settings: settings, constraints: constraints)
        return try resolver.resolve(graph: graph, path)
    }

    private func path(graph: Graph, from: GraphPathElement, to: GraphPathElement?, currentPath: GraphPath) -> GraphPath? {
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

        guard constraints.shouldInclude(node: node, currentPath: currentPath, to: to) else {
            debug("Node \(node.name) (with ID \(node)) should not be included, backtracking from current path \(currentPath.toStrings)")
            return nil
        }

        let endingElement = GraphPathElement.ending(node, entrySocketId)

        if let to = to, to.isSame(as: endingElement) {
            // If the destination node is specified and is the same as the current element,
            // we have reached the destination node
            return currentPath + endingElement
        } else if constraints.reachedDestination(node: node, to: to) {
            return currentPath + endingElement
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

            if let path = path(graph: graph,
                               from: betweenElement,
                               to: to,
                               currentPath: currentPath + .between(node, entrySocketId, exitSocket))
            {
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
