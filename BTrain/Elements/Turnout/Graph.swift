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

protocol Graph {
    func edge(from: Node, socketId: SocketId) -> Edge?
    
    func node(for: GraphElementId) -> Node?
}

// A node in a graph. Conceptually, a node represents either a turnout or a block.
protocol Node {
    var identifier: GraphElementId { get }
    
    // Returns all the sockets available for that node
    var sockets: [SocketId] { get }
    
    // Returns all the sockets reachable from a specific socket
    func reachableSockets(from socket: SocketId) -> [SocketId]
}

// Link between two nodes
protocol Edge {
    var identifier: GraphElementId { get }
    
    var fromNode: GraphElementId { get }
    var fromNodeSocket: SocketId? { get }
    
    var toNode: GraphElementId { get }
    var toNodeSocket: SocketId? { get }
}

struct PathElement: Equatable {
    
    static func == (lhs: PathElement, rhs: PathElement) -> Bool {
        return lhs.node.identifier == rhs.node.identifier && lhs.enterSocket == rhs.enterSocket && lhs.exitSocket == rhs.exitSocket
    }
    
    let node: Node
    let exitSocket: SocketId?
    let enterSocket: SocketId?
    
    static func starting(_ node: Node, _ exitSocket: SocketId) -> PathElement {
        .init(node: node, exitSocket: exitSocket, enterSocket: nil)
    }
    
    static func ending(_ node: Node, _ enterSocket: SocketId) -> PathElement {
        .init(node: node, exitSocket: nil, enterSocket: enterSocket)
    }
    
    static func between(_ node: Node, _ enterSocket: SocketId, _ exitSocket: SocketId) -> PathElement {
        .init(node: node, exitSocket: exitSocket, enterSocket: enterSocket)
    }
}

typealias GraphPath = [PathElement]

final class GraphPathFinder {
    
    func path(graph: Graph, from: Node, to: Node) -> GraphPath? {
        for socketId in from.sockets {
            for toSocketId in to.sockets {
                if let steps = path(graph: graph, from: PathElement.starting(from, socketId), to: PathElement.ending(to, toSocketId), visitedNodes: [], currentPath: [PathElement.starting(from, socketId)]) {
                    return steps
                }
            }
        }
        return nil
    }
    
    func path(graph: Graph, from: PathElement, to: PathElement, visitedNodes: [Node], currentPath: GraphPath) -> GraphPath? {

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
        
        let endingElement = PathElement.ending(node, enterSocketId)
        if endingElement == to {
            // We reached the destination node
            return currentPath + [endingElement]
        }

        // We haven't reached the destination node, keep going forward
        // by exploring all the possible exit sockets from `node`
        let exitSockets = node.reachableSockets(from: enterSocketId)
        for exitSocket in exitSockets {
            let betweenElement = PathElement.between(node, enterSocketId, exitSocket)
            if let path = path(graph: graph, from: betweenElement, to: to,
                               visitedNodes: visitedNodes + [node],
                               currentPath: currentPath + [PathElement.between(node, enterSocketId, exitSocket)]) {
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
            if let p = pf.path(graph: graph, from: previousElement, to: element, visitedNodes: [], currentPath: []) {
                for resolvedElement in p.dropLast() {
                    resolvedPath.append(resolvedElement)
                }
            }
            resolvedPath.append(element)
            previousElement = element
        }
        return resolvedPath
    }
}

// Extensions

extension Block: Node {
    var identifier: GraphElementId {
        id.uuid
    }
    
    var sockets: [SocketId] {
        allSockets.compactMap { $0.socketId }
    }
    
    func reachableSockets(from socket: SocketId) -> [SocketId] {
        if socket == Block.previousSocket {
            return [Block.nextSocket]
        } else {
            return [Block.previousSocket]
        }
    }
        
}

extension Turnout: Node {
    var identifier: GraphElementId {
        id.uuid
    }
    
    var sockets: [SocketId] {
        allSockets.compactMap { $0.socketId }
    }
    
    func reachableSockets(from socket: SocketId) -> [SocketId] {
        sockets(from: socket)
    }
    
}

extension ITransition {
    var identifier: GraphElementId {
        id.uuid
    }
    
    var fromNode: GraphElementId {
        if let block = a.block {
            return block.uuid
        } else if let turnout = a.turnout {
            return turnout.uuid
        } else {
            fatalError("Socket must specify a block or a turnout")
        }
    }
    
    var fromNodeSocket: SocketId? {
        return a.socketId
    }
    
    var toNode: GraphElementId {
        if let block = b.block {
            return block.uuid
        } else if let turnout = b.turnout {
            return turnout.uuid
        } else {
            fatalError("Socket must specify a block or a turnout")
        }
    }
    
    var toNodeSocket: SocketId? {
        return b.socketId
    }
    
}

extension Layout: Graph {
    func edge(from: Node, socketId: SocketId) -> Edge? {
        let socket: Socket
        if let block = block(for: Identifier<Block>(uuid: from.identifier)) {
            socket = Socket.block(block.id, socketId: socketId)
        } else if let turnout = turnout(for: Identifier<Turnout>(uuid: from.identifier)) {
            socket = Socket.turnout(turnout.id, socketId: socketId)
        } else {
            return nil
        }

        return try? transition(from: socket)
    }
    
    func node(for elementId: GraphElementId) -> Node? {
        if let block = block(for: Identifier<Block>(uuid: elementId)) {
            return block
        } else if let turnout = turnout(for: Identifier<Turnout>(uuid: elementId)) {
            return turnout
        } else {
            return nil
        }
    }
        
}