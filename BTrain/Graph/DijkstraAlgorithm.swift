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
        case shortestDistanceNodeNotFound(node: GraphNode)
        case nodeNotFound(identifier: GraphElementIdentifier)
        case elementIdentifierNotFound(uuid: String)
    }
    
    let graph: Graph
    
    var elementIdentifiers = [String:GraphElementIdentifier]()
    var distances = [String:Double]()
    var visitedNodes = Set<String>()
    var evaluatedButNotVisitedNodes = Set<String>()

    private init(graph: Graph) {
        self.graph = graph
    }
    
    static func shortestPath(graph: Graph, from: GraphNode, to: GraphNode) throws -> [GraphElementIdentifier] {
        return try DijkstraAlgorithm(graph: graph).shortestPath(from: from, to: to).reversed()
    }
    
    private func shortestPath(from: GraphNode, to: GraphNode) throws -> [GraphElementIdentifier] {
        distances[from.identifier.uuid] = 0
        evaluatedButNotVisitedNodes.insert(from.identifier.uuid)
        elementIdentifiers[from.identifier.uuid] = from.identifier
        
        try visitGraph(from: from, to: to)
        
        // Now go from to back until from is reached, following the nodes
        // with the smallest distance.
        print("Distances:")
        for item in distances.sorted(by: { $0.key < $1.key }) {
            print("\(item.key) = \(item.value)")
        }
        
        return try buildShortestPath(from: to, to: from, path: [to.identifier])
    }
    
    private func buildShortestPath(from: GraphNode, to: GraphNode, path: [GraphElementIdentifier]) throws -> [GraphElementIdentifier] {
        if from.identifier.uuid == to.identifier.uuid {
            return path
        }
        
        var shortestDistance: Double = .infinity
        var shortestDistanceNodeIdentifier: GraphElementIdentifier?
        
        for socket in from.sockets {
            guard let edge = graph.edge(from: from, socketId: socket) else {
                continue
            }
            
            let toIdentifier = edge.toNode.uuid
            if let distance = distances[toIdentifier], distance < shortestDistance {
                shortestDistance = distance
                shortestDistanceNodeIdentifier = edge.toNode
            }
        }
        
        guard let shortestDistanceNodeIdentifier = shortestDistanceNodeIdentifier else {
            throw DijkstraError.shortestDistanceNodeNotFound(node: from)
        }
        
        guard let node = graph.node(for: shortestDistanceNodeIdentifier) else {
            throw DijkstraError.nodeNotFound(identifier: shortestDistanceNodeIdentifier)
        }
        
        return try buildShortestPath(from: node, to: to, path: path + [shortestDistanceNodeIdentifier])
    }
    
    private func visitGraph(from: GraphNode, to: GraphNode) throws {
        guard !visitedNodes.contains(from.identifier.uuid) else {
            return
        }
        
        visitedNodes.insert(from.identifier.uuid)
        evaluatedButNotVisitedNodes.remove(from.identifier.uuid)

        let fromNodeDistance = distances[from.identifier.uuid]!
        for socket in from.sockets {
            guard let edge = graph.edge(from: from, socketId: socket) else {
                continue
            }
            
            guard let adjacentNode = graph.node(for: edge.toNode) else {
                continue
            }
                        
            guard !visitedNodes.contains(adjacentNode.identifier.uuid) else {
                continue
            }
            
            let adjacentNodeDistance = fromNodeDistance + adjacentNode.weight
            if let existingDistance = distances[adjacentNode.identifier.uuid], existingDistance < adjacentNodeDistance {
                continue
            }
            
            distances[adjacentNode.identifier.uuid] = adjacentNodeDistance
            evaluatedButNotVisitedNodes.insert(adjacentNode.identifier.uuid)
            elementIdentifiers[adjacentNode.identifier.uuid] = adjacentNode.identifier
        }
        
        // Pick the node with the smallest distance
        let evaluatedNodes: [GraphNode] = try evaluatedButNotVisitedNodes.compactMap { uuid in
            guard let identifier = elementIdentifiers[uuid] else {
                throw DijkstraError.elementIdentifierNotFound(uuid: uuid)
            }
            return graph.node(for: identifier)
        }
        
        guard let smallestNode = evaluatedNodes.sorted(by: { distances[$0.identifier.uuid]! < distances[$1.identifier.uuid]! }).first else {
            // This happens when there are no edges out of the `from` node or when all the adjacent nodes of `from` have been evaluated.
            return
        }
                
        print("Smallest distance node is \(smallestNode.identifier.uuid) with distance \(distances[smallestNode.identifier.uuid]!)")

        try visitGraph(from: smallestNode, to: to)
    }
}

extension DijkstraAlgorithm.DijkstraError: LocalizedError {
    
    var errorDescription: String? {
        switch self {
        case .shortestDistanceNodeNotFound(node: let node):
            return "Shortest distance adjacent node not found for \(node.identifier)"
        case .nodeNotFound(identifier: let identifier):
            return "Node \(identifier) not found in graph"
        case .elementIdentifierNotFound(uuid: let uuid):
            return "Element identifier \(uuid) not found"
        }
    }
}
