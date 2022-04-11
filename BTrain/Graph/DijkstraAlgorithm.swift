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

final class DijkstraAlgorithm {
    
    let graph: Graph
    
    var elementIdentifiers = [String:GraphElementIdentifier]()
    var distances = [String:Double]()
    var visitedNodes = Set<String>()
    var evaluatedButNotVisitedNodes = Set<String>()

    init(graph: Graph) {
        self.graph = graph
    }
    
    func shortestPath(from: GraphNode, to: GraphNode) -> [GraphElementIdentifier] {
        distances.removeAll()
        
        distances[from.identifier.uuid] = 0
        evaluatedButNotVisitedNodes.insert(from.identifier.uuid)
        elementIdentifiers[from.identifier.uuid] = from.identifier
        
        visitGraph(from: from, to: to)
        
        // Now go from to back until from is reached, following the nodes
        // with the smallest distance.
        for item in distances.sorted(by: { $0.key < $1.key }) {
            print("\(item.key) = \(item.value)")
        }
        
        return buildShortestPath(from: to, to: from, path: [])
    }
    
    private func buildShortestPath(from: GraphNode, to: GraphNode, path: [GraphElementIdentifier]) -> [GraphElementIdentifier] {
        if from.identifier.uuid == to.identifier.uuid {
            return path
        }
        
        var smallestDistance: Double = .infinity
        var smallestDistanceNode: GraphElementIdentifier?
        
        for socket in from.sockets {
            guard let edge = graph.edge(from: from, socketId: socket) else {
                continue
            }
            
            let toIdentifier = edge.toNode.uuid
            if let distance = distances[toIdentifier], distance < smallestDistance {
                smallestDistance = distance
                smallestDistanceNode = edge.toNode
            }
        }
        
        if let smallestDistanceNode = smallestDistanceNode, let node = graph.node(for: smallestDistanceNode) {
            return buildShortestPath(from: node, to: to, path: path + [smallestDistanceNode])
        } else {
            fatalError()
        }
    }
    
    private func visitGraph(from: GraphNode, to: GraphNode) {
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
        let evaluatedNodes: [GraphNode] = evaluatedButNotVisitedNodes.compactMap { uuid in
            guard let identifier = elementIdentifiers[uuid] else {
                return nil
            }
            return graph.node(for: identifier)
        }
        
        guard let smallestNode = evaluatedNodes.sorted(by: { distances[$0.identifier.uuid]! < distances[$1.identifier.uuid]! }).first else {
            return
        }
                
        print("Smallest distance node is \(smallestNode.identifier.uuid) with distance \(distances[smallestNode.identifier.uuid]!)")

        visitGraph(from: smallestNode, to: to)
    }
}
