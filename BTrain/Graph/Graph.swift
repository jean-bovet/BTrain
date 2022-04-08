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

// A socket identifier. A socket is where an edge exits (or enters) a node.
// For example:
// - A block is represented by a node with two sockets: an entry socket and an exit socket.
// - A turnout is a node with 3 or more sockets: typically one entry socket and two exit sockets.
typealias SocketId = Int
typealias GraphElementId = String

// Defines a generic graph consisting of nodes and edges.
// See https://en.wikipedia.org/wiki/Graph_(discrete_mathematics)
protocol Graph {
    // Returns the edge that starts at `from` node from the specified `socketId`.
    func edge(from: GraphNode, socketId: SocketId) -> GraphEdge?
    
    // Returns the node corresponding to the identifier by `for`
    func node(for: GraphElementId) -> GraphNode?
}

// A node in a graph. Conceptually, a node represents either a turnout or a block.
protocol GraphNode {
    // The unique identifier of the node
    var identifier: GraphElementId { get }
    
    // Returns all the sockets available for that node
    var sockets: [SocketId] { get }
    
    // Returns all the sockets reachable from a specific socket
    func reachableSockets(from socket: SocketId) -> [SocketId]
}

// Link between two nodes
protocol GraphEdge {
    // The unique identifier of the edge
    var identifier: GraphElementId { get }
    
    var fromNode: GraphElementId { get }
    var fromNodeSocket: SocketId? { get }
    
    var toNode: GraphElementId { get }
    var toNodeSocket: SocketId? { get }
}

// A path consists of an array of elements.
typealias GraphPath = [GraphPathElement]

// Each element is a `node` with specified exit and enter sockets.
// A starting element only has an exit socket while the last
// element in the path only has an enter socket.
struct GraphPathElement: Equatable, CustomStringConvertible {
        
    let node: GraphNode
    let entrySocket: SocketId?
    let exitSocket: SocketId?

    var description: String {
        var text = ""
        if let enterSocket = entrySocket {
            text += "\(enterSocket):"
        }
        text += node.identifier
        if let exitSocket = exitSocket {
            text += ":\(exitSocket)"
        }
        return text
    }
    
    // Returns true if this element is the same as the other element, taking into account the fact that the entry or exit socket can be nil.
    // The following rules are used:
    // - Both element must refer to the same node identifier
    // - If this element's entrySocket is not nil, it must correspond to the other element's entrySocket. Otherwise, the entrySocket is ignored.
    // - If this element's exitSocket is not nil, it must correspond to the other element's exitSocket. Otherwise, the exitSocket is ignored.
    func isSame(as other: GraphPathElement) -> Bool {
        guard node.identifier == other.node.identifier else {
            return false
        }
        
        if let entrySocket = entrySocket, entrySocket != other.entrySocket {
            return false
        }
        
        if let exitSocket = exitSocket, exitSocket != other.exitSocket {
            return false
        }

        return true
    }
    
    static func starting(_ node: GraphNode, _ exitSocket: SocketId) -> GraphPathElement {
        .init(node: node, entrySocket: nil, exitSocket: exitSocket)
    }
    
    static func ending(_ node: GraphNode, _ entrySocket: SocketId?) -> GraphPathElement {
        .init(node: node, entrySocket: entrySocket, exitSocket: nil)
    }
    
    static func between(_ node: GraphNode, _ entrySocket: SocketId, _ exitSocket: SocketId) -> GraphPathElement {
        .init(node: node, entrySocket: entrySocket, exitSocket: exitSocket)
    }
    
    static func == (lhs: GraphPathElement, rhs: GraphPathElement) -> Bool {
        return lhs.node.identifier == rhs.node.identifier && lhs.entrySocket == rhs.entrySocket && lhs.exitSocket == rhs.exitSocket
    }
    
}

extension GraphPath where Element == GraphPathElement {
    
    func contains(_ element: GraphPathElement) -> Bool {
        return contains { otherElement in
            return element == otherElement
        }
    }
}

protocol GraphPathFinding {
    
    func path(graph: Graph, from: GraphNode, to: GraphNode?, constraints: GraphPathFinderConstraints) -> GraphPath?
    
    func path(graph: Graph, from: GraphPathElement, to: GraphPathElement?, constraints: GraphPathFinderConstraints) -> GraphPath?
    
}

struct GraphPathFinder: GraphPathFinding {
            
    struct Settings {
        let verbose: Bool
        let random: Bool
        let overflow: Int
    }
    
    let settings: Settings
    
    init(settings: Settings) {
        self.settings = settings
    }
    
    final class DefaultConstraints: GraphPathFinderConstraints {
        
        func shouldInclude(node: GraphNode, currentPath: GraphPath, to: GraphPathElement?) -> Bool {
            return true
        }
        
        func reachedDestination(node: GraphNode, to: GraphPathElement?) -> Bool {
            return false
        }

    }

    func shortestPath(graph: Graph, from: GraphNode, to: GraphNode?, constraints: GraphPathFinderConstraints = DefaultConstraints()) -> GraphPath? {
        return shortestPath {
            path(graph: graph, from: from, to: to, constraints: constraints)
        }
    }
    
    func shortestPath(graph: Graph, from: GraphPathElement, to: GraphPathElement?, constraints: GraphPathFinderConstraints = DefaultConstraints()) -> GraphPath? {
        return shortestPath {
            path(graph: graph, from: from, to: to, constraints: constraints)
        }
    }
    
    func path(graph: Graph, from: GraphNode, to: GraphNode?, constraints: GraphPathFinderConstraints = DefaultConstraints()) -> GraphPath? {
        for socketId in shuffled(from.sockets) {
            if let to = to {
                for toSocketId in shuffled(to.sockets) {
                    if let steps = path(graph: graph, from: .starting(from, socketId), to: .ending(to, toSocketId), currentPath: [.starting(from, socketId)], constraints: constraints) {
                        return steps
                    }
                }
            } else {
                if let steps = path(graph: graph, from: .starting(from, socketId), to: nil, currentPath: [.starting(from, socketId)], constraints: constraints) {
                    return steps
                }
            }
        }
        return nil
    }

    func path(graph: Graph, from: GraphPathElement, to: GraphPathElement?, constraints: GraphPathFinderConstraints = DefaultConstraints()) -> GraphPath? {
        return path(graph: graph, from: from, to: to, currentPath: [from], constraints: constraints)
    }
    
    func resolve(graph: Graph, _ path: GraphPath, constraints: GraphPathFinderConstraints = DefaultConstraints()) -> GraphPath? {
        var resolvedPath = GraphPath()
        guard var previousElement = path.first else {
            return nil
        }
        resolvedPath.append(previousElement)
        for element in path.dropFirst() {
            if let p = self.path(graph: graph, from: previousElement, to: element, constraints: constraints) {
                for resolvedElement in p.dropFirst() {
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
        return resolvedPath
    }

    // Note: until we have a proper algorithm that finds the shortest path in a single pass,
    // we will generate a few paths and pick the shortest one.
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
            debug("Current path is overflowing, backtracking")
            return nil
        }
        
        guard from != to else {
            return currentPath
        }
        
        guard let exitSocket = from.exitSocket else {
            debug("No exit socket defined for \(from.node)")
            return nil
        }
        
        guard let edge = graph.edge(from: from.node, socketId: exitSocket) else {
            debug("No edge found from \(from.node) and socket \(exitSocket)")
            return nil
        }
        
        guard let node = graph.node(for: edge.toNode) else {
            debug("No destination node found in graph for \(edge.toNode)")
            return nil
        }
                
        guard let entrySocketId = edge.toNodeSocket else {
            debug("No entry socket for destination node \(node) in graph")
            return nil
        }
                
        let endingElement = GraphPathElement.ending(node, entrySocketId)
        
        if !constraints.shouldInclude(node: node, currentPath: currentPath, to: to) {
            debug("Node \(node) should not be included, backtracking")
            return nil
        }
                
        if let to = to, to.isSame(as: endingElement) {
            // We reached the destination node
            return currentPath + [endingElement]
        } else if constraints.reachedDestination(node: node, to: to) {
            // If no target node is specified, let's determine if the node one that we should stop at.
            return currentPath + [endingElement]
        }

        // We haven't reached the destination node, keep going forward
        // by exploring all the possible exit sockets from `node`
        let exitSockets = node.reachableSockets(from: entrySocketId)
        for exitSocket in shuffled(exitSockets) {
            let betweenElement = GraphPathElement.between(node, entrySocketId, exitSocket)
            
            guard !currentPath.contains(betweenElement) else {
                debug("Node \(betweenElement) is already part of the path, backtracking")
                // Continue to the next socket as this socket (in combination with the entrySocketId)
                // has already been used in the path
                continue
            }
            
            if let path = path(graph: graph, from: betweenElement, to: to,
                               currentPath: currentPath + [.between(node, entrySocketId, exitSocket)],
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

protocol GraphPathFinderConstraints {
    // Returns true if the specified node should be included in the path.
    // If false, the algorithm backtracks to the previous node and finds
    // an alternative edge if possible.
    func shouldInclude(node: GraphNode, currentPath: GraphPath, to: GraphPathElement?) -> Bool
    
    // Returns true if the specified node is the destination node of the path.
    func reachedDestination(node: GraphNode, to: GraphPathElement?) -> Bool

}

extension Array where Element == GraphPathElement {
    
    var toStrings: [String] {
        map { $0.description }
    }
}
