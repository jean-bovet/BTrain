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
typealias SocketId = Int

// The identifier for an element in the graph (node or edge)
protocol GraphElementIdentifier {
    
    // Returns the unique identifier
    var uuid: String { get }
    
}

// Defines a generic graph consisting of nodes and edges.
// See https://en.wikipedia.org/wiki/Graph_(discrete_mathematics)
protocol Graph {
    // Returns the edge that starts at `from` node from the specified `socketId`.
    func edge(from: GraphNode, socketId: SocketId, constraints: LayoutPathFinder.LayoutConstraints) -> GraphEdge?
    
    // Returns the node corresponding to the identifier by `for`
    func node(for: GraphElementIdentifier, constraints: LayoutPathFinder.LayoutConstraints) -> GraphNode?
}

/// A node in a graph.
///
/// Conceptually, a node represents either a turnout or a block.
protocol GraphNode {
    /// The unique identifier of the node
    var identifier: GraphElementIdentifier { get }
    
    /// The name of the node
    var name: String { get }
    
    /// Returns the weight of the node given the specified constraints
    /// - Parameter constraints: the constraints
    /// - Returns: the weight of the node
    ///
    func weight(_ constraints: LayoutPathFinder.LayoutConstraints) -> Double
    
    /// Returns all the available sockets for the node given the specified constraints
    /// - Parameter constraints: the constraints
    /// - Returns: the available sockets
    func sockets(_ constraints: LayoutPathFinder.LayoutConstraints) -> [SocketId]
        
    /// Returns all the sockets reachable from a specific socket, given the specified constraints.
    ///
    /// In other words, given a specific edge entering the node and constraints,
    /// what are the other edges that can be reached when exiting this node.
    /// - Parameters:
    ///   - socket: the socket specifying where the path enters the node
    ///   - constraints: the constraints
    /// - Returns: an array of sockets
    func reachableSockets(from socket: SocketId, _ constraints: LayoutPathFinder.LayoutConstraints) -> [SocketId]
}

// Link between two nodes
protocol GraphEdge {
    // The unique identifier of the edge
    var identifier: GraphElementIdentifier { get }
    
    var fromNode: GraphElementIdentifier { get }
    var fromNodeSocket: SocketId? { get }
    
    var toNode: GraphElementIdentifier { get }
    var toNodeSocket: SocketId? { get }
}
