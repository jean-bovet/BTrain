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

/// This class implements the Dijkstra algorithm that finds the shortest path in a graph
/// See https://en.wikipedia.org/wiki/Dijkstra%27s_algorithm
final class DijkstraAlgorithm {
    
    enum DijkstraError: Error {
        case shortestDistanceNodeNotFound(node: GraphPathElement)
        case nodeNotFound(identifier: GraphElementIdentifier)
        case elementIdentifierNotFound(uuid: String)
    }
    
    let graph: Graph
    
    var distances = [GraphPathElement:Double]()
    var visitedElements = Set<GraphPathElement>()
    var evaluatedButNotVisitedElements = Set<GraphPathElement>()

    private init(graph: Graph) {
        self.graph = graph
    }
    
    static func shortestPath(graph: Graph, from: GraphPathElement, to: GraphPathElement) throws -> GraphPath {
        return try DijkstraAlgorithm(graph: graph).shortestPath(from: from, to: to).reversed
    }
    
    private func shortestPath(from: GraphPathElement, to: GraphPathElement) throws -> GraphPath {
        distances[from] = 0
        evaluatedButNotVisitedElements.insert(from)
        
        try visitGraph(from: from, to: to)
        
        // Now go from to back until from is reached, following the nodes
        // with the smallest distance.
        print("Distances:")
        for item in distances.sorted(by: { $0.key.node.identifier.uuid < $1.key.node.identifier.uuid }) {
            print("\(item.key) = \(item.value)")
        }
        
        return try buildShortestPath(from: to, to: from, path: .init([to]))
    }
    
    private func buildShortestPath(from: GraphPathElement, to: GraphPathElement, path: GraphPath) throws -> GraphPath {
        if from == to {
            return path
        }

        var shortestDistance: Double = .infinity
        var shortestDistanceElement: GraphPathElement?

        for socket in from.node.sockets {
            guard let edge = graph.edge(from: from.node, socketId: socket) else {
                continue
            }

            guard let previousNode = graph.node(for: edge.toNode) else {
                throw DijkstraError.nodeNotFound(identifier: edge.toNode)
            }

            // TODO: need to introduce some constraints here when using the turnout/block
//            let element = GraphPathElement.starting(previousNode, socket)
            let element = GraphPathElement.any(previousNode)
            if let distance = distances[element], distance < shortestDistance {
                shortestDistance = distance
                shortestDistanceElement = element
            }
        }

        guard let shortestDistanceNodeIdentifier = shortestDistanceElement else {
            throw DijkstraError.shortestDistanceNodeNotFound(node: from)
        }

        return try buildShortestPath(from: shortestDistanceNodeIdentifier, to: to, path: path.appending(shortestDistanceNodeIdentifier))
    }
    
    private func visitGraph(from: GraphPathElement, to: GraphPathElement) throws {
        guard !visitedElements.contains(from) else {
            return
        }
        
        visitedElements.insert(from)
        evaluatedButNotVisitedElements.remove(from)

        let fromNodeDistance = distances[from]!
        for socket in from.node.sockets {
            guard let edge = graph.edge(from: from.node, socketId: socket) else {
                continue
            }
            
            guard let adjacentNode = graph.node(for: edge.toNode) else {
                continue
            }
                        
            // TODO: need to introduce some constraints here when using the turnout/block
//            let adjacentElement = GraphPathElement.ending(adjacentNode, socket)
            let adjacentElement = GraphPathElement.any(adjacentNode)
            guard !visitedElements.contains(adjacentElement) else {
                continue
            }
            
            let adjacentNodeDistance = fromNodeDistance + adjacentNode.weight
            if let existingDistance = distances[adjacentElement], existingDistance < adjacentNodeDistance {
                continue
            }
            
            distances[adjacentElement] = adjacentNodeDistance
            evaluatedButNotVisitedElements.insert(adjacentElement)
        }
        
        // Pick the node with the smallest distance
        guard let shortestDistanceElement = evaluatedButNotVisitedElements.sorted(by: { distances[$0]! < distances[$1]! }).first else {
            // This happens when there are no edges out of the `from` node or when all the adjacent nodes of `from` have been evaluated.
            return
        }
                
        print("Smallest distance node is \(shortestDistanceElement) with distance \(distances[shortestDistanceElement]!)")

        try visitGraph(from: shortestDistanceElement, to: to)
    }
}

extension DijkstraAlgorithm.DijkstraError: LocalizedError {
    
    var errorDescription: String? {
        switch self {
        case .shortestDistanceNodeNotFound(node: let node):
            return "Shortest distance adjacent node not found for \(node)"
        case .nodeNotFound(identifier: let identifier):
            return "Node \(identifier) not found in graph"
        case .elementIdentifierNotFound(uuid: let uuid):
            return "Element identifier \(uuid) not found"
        }
    }
}
