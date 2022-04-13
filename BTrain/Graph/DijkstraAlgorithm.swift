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
        
        // Visit the graph and assign distances to all the nodes until the `to` node is reached
        try visitGraph(from: from, to: to)
        
        // Now go from to back until from is reached, following the nodes
        // with the smallest distance.
        print("Distances:")
        for item in distances.sorted(by: { $0.key.node.identifier.uuid < $1.key.node.identifier.uuid }) {
            print("\(item.key) = \(item.value)")
        }
        
        // Now that the distances are assigned, find the shortest path
        return try buildShortestPath(from: from, to: to)
    }
    
    // Now that the graph has been evaluated and distances assigned to all the nodes,
    // we need to find the shortest path from the node `from` to `to`. This is done
    // by starting with the `to` node, walking backwards until we find `from`, by choosing
    // the node that has the shortest distance assigned to it.
    private func buildShortestPath(from: GraphPathElement, to: GraphPathElement) throws -> GraphPath {
        let buildFrom = to.inverse
        let buildTo = from.inverse
        print("Build path \(buildFrom) > \(buildTo)")
        return try buildShortestPath(from: buildFrom, to: buildTo, path: .init([buildFrom]))
    }
    
    private func buildShortestPath(from: GraphPathElement, to: GraphPathElement, path: GraphPath) throws -> GraphPath {
        if to.isSame(as: from) {
            return path
        }

        //TODO: exitSocket can be nil!
        guard let edge = graph.edge(from: from.node, socketId: from.exitSocket!) else {
            fatalError()
        }
        
        guard let node = graph.node(for: edge.toNode) else {
            throw DijkstraError.nodeNotFound(identifier: edge.toNode)
        }

        var shortestDistance: Double = .infinity
        var shortestDistanceElement: GraphPathElement?

        // TODO: toNodeSocket can be nil!
        print("From \(from.description): \(node.reachableSockets(from: edge.toNodeSocket!))")
        for socket in node.reachableSockets(from: edge.toNodeSocket!) {
            let element = GraphPathElement.between(node, socket, edge.toNodeSocket!)
            if let distance = distances[element] {
                print(" * \(element) = \(distance) and shortest distance so far is \(shortestDistance)")
                if distance < shortestDistance {
                    shortestDistance = distance
                    shortestDistanceElement = element
                }
            } else {
                fatalError()
            }
        }

        guard let shortestDistanceElement = shortestDistanceElement?.inverse else {
            throw DijkstraError.shortestDistanceNodeNotFound(node: from)
        }

        print("Selected \(shortestDistanceElement.description) with distance \(shortestDistance)")
        return try buildShortestPath(from: shortestDistanceElement, to: to, path: path.appending(shortestDistanceElement))
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
                
            guard let entrySocket = edge.toNodeSocket else {
                // TODO: throw exception if edge.toNotSocket is nil
                fatalError()
            }
            
            for exitSocket in adjacentNode.reachableSockets(from: entrySocket) {
                let adjacentElement = GraphPathElement.between(adjacentNode, entrySocket, exitSocket)
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

extension GraphPathElement {
    
    var inverse: GraphPathElement {
        if let entrySocket = entrySocket, let exitSocket = exitSocket {
            return .between(node, exitSocket, entrySocket)
        } else if let entrySocket = entrySocket {
            return .starting(node, entrySocket)
        } else if let exitSocket = exitSocket {
            return .ending(node, exitSocket)
        } else {
            fatalError("Invalid element")
        }
    }
}
