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

// A socket identifier. A socket is where an edge exists (or enter) a node.
// For example:
// - A block is represented by a node with two sockets: an entry socket and an exit socket.
// - A turnout is a node with 3 or more sockets: typically one entry socket and two exit sockets.
typealias SocketId = Int
typealias GraphElementId = String

// Defines a generic graph that returns nodes or edges
protocol Graph {
    func edge(from: GraphNode, socketId: SocketId) -> GraphEdge?
    
    func node(for: GraphElementId) -> GraphNode?
}

// A node in a graph. Conceptually, a node represents either a turnout or a block.
protocol GraphNode {
    var identifier: GraphElementId { get }
    
    // Returns all the sockets available for that node
    var sockets: [SocketId] { get }
    
    // Returns all the sockets reachable from a specific socket
    func reachableSockets(from socket: SocketId) -> [SocketId]
}

// Link between two nodes
protocol GraphEdge {
    var identifier: GraphElementId { get }
    
    var fromNode: GraphElementId { get }
    var fromNodeSocket: SocketId? { get }
    
    var toNode: GraphElementId { get }
    var toNodeSocket: SocketId? { get }
}

struct GraphPathElement: Equatable {
    
    static func == (lhs: GraphPathElement, rhs: GraphPathElement) -> Bool {
        return lhs.node.identifier == rhs.node.identifier && lhs.enterSocket == rhs.enterSocket && lhs.exitSocket == rhs.exitSocket
    }
    
    let node: GraphNode
    let exitSocket: SocketId?
    let enterSocket: SocketId?
    
    static func starting(_ node: GraphNode, _ exitSocket: SocketId) -> GraphPathElement {
        .init(node: node, exitSocket: exitSocket, enterSocket: nil)
    }
    
    static func ending(_ node: GraphNode, _ enterSocket: SocketId) -> GraphPathElement {
        .init(node: node, exitSocket: nil, enterSocket: enterSocket)
    }
    
    static func between(_ node: GraphNode, _ enterSocket: SocketId, _ exitSocket: SocketId) -> GraphPathElement {
        .init(node: node, exitSocket: exitSocket, enterSocket: enterSocket)
    }
}

typealias GraphPath = [GraphPathElement]

protocol GraphPathFinderDelegate: AnyObject {
    // Returns true if the specified node should be included in the path.
    // If false, the algorithm backtracks to the previous node and finds
    // an alternative edge if possible.
    func shouldInclude(node: GraphNode) -> Bool
    
    // Returns true if the specified node is the destination node of the path.
    func reachedDestination(node: GraphNode) -> Bool
}

final class GraphPathFinder {
    
    weak var delegate: GraphPathFinderDelegate?
    
    func path(graph: Graph, from: GraphNode, to: GraphNode?) -> GraphPath? {
        for socketId in from.sockets {
            if let to = to {
                for toSocketId in to.sockets {
                    if let steps = path(graph: graph, from: GraphPathElement.starting(from, socketId), to: GraphPathElement.ending(to, toSocketId), visitedNodes: [], currentPath: [GraphPathElement.starting(from, socketId)]) {
                        return steps
                    }
                }
            } else {
                if let steps = path(graph: graph, from: GraphPathElement.starting(from, socketId), to: nil, visitedNodes: [], currentPath: [GraphPathElement.starting(from, socketId)]) {
                    return steps
                }
            }
        }
        return nil
    }

    func path(graph: Graph, from: GraphPathElement, to: GraphPathElement?) -> GraphPath? {
        return path(graph: graph, from: from, to: to, visitedNodes: [], currentPath: [from])
    }
    
    private func path(graph: Graph, from: GraphPathElement, to: GraphPathElement?, visitedNodes: [GraphNode], currentPath: GraphPath) -> GraphPath? {

        guard from != to else {
            return currentPath
        }
        
        guard let edge = graph.edge(from: from.node, socketId: from.exitSocket!) else {
            return nil
        }
        
        guard let node = graph.node(for: edge.toNode), !visitedNodes.contains(where: { $0.identifier == node.identifier} ) else {
            return nil
        }
                
        guard let enterSocketId = edge.toNodeSocket else {
            return nil
        }
        
        let endingElement = GraphPathElement.ending(node, enterSocketId)

        if let delegate = delegate {
            if !delegate.shouldInclude(node: node) {
                return nil
            }
            if delegate.reachedDestination(node: node) {
                return currentPath + [endingElement]
            }
        }
        
        if endingElement == to {
            // We reached the destination node
            return currentPath + [endingElement]
        }

        // We haven't reached the destination node, keep going forward
        // by exploring all the possible exit sockets from `node`
        let exitSockets = node.reachableSockets(from: enterSocketId)
        for exitSocket in exitSockets {
            let betweenElement = GraphPathElement.between(node, enterSocketId, exitSocket)
            if let path = path(graph: graph, from: betweenElement, to: to,
                               visitedNodes: visitedNodes + [node],
                               currentPath: currentPath + [GraphPathElement.between(node, enterSocketId, exitSocket)]) {
                return path
            }
        }

        return nil
    }

}

final class GraphPathResolver {

    func resolve(graph: Graph, _ path: GraphPath) -> GraphPath? {
        var resolvedPath = GraphPath()
        guard var previousElement = path.first else {
            return nil
        }
        resolvedPath.append(previousElement)
        for element in path.dropFirst() {
            let pf = GraphPathFinder()
            if let p = pf.path(graph: graph, from: previousElement, to: element) {
                for resolvedElement in p.dropFirst() {
                    resolvedPath.append(resolvedElement)
                }
            }
            previousElement = element
        }
        return resolvedPath
    }
}
