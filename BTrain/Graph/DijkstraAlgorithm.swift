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

    // The comments in this class will follow this graph as an illustration
    //┌─────────┐                      ┌─────────┐             ┌─────────┐
    //│   s1    │───▶  t1  ───▶  t2  ─▶│   b1    │─▶  t4  ────▶│   s2    │
    //└─────────┘                      └─────────┘             └─────────┘
    //     ▲            │         │                    ▲            │
    //     │            │         │                    │            │
    //     │            ▼         ▼                    │            │
    //     │       ┌─────────┐                    ┌─────────┐       │
    //     │       │   b2    │─▶ t3  ────────────▶│   b3    │       │
    //     │       └─────────┘                    └─────────┘       ▼
    //┌─────────┐                                              ┌─────────┐
    //│   b5    │◀─────────────────────────────────────────────│   b4    │
    //└─────────┘                                              └─────────┘


    enum DijkstraError: Error {
        case shortestDistanceNodeNotFound(node: GraphPathElement)
        case nodeNotFound(identifier: GraphElementIdentifier)
        case elementIdentifierNotFound(uuid: String)
    }
    
    let graph: Graph
    
    private let verbose = true
    
    private var distances = [GraphPathElement:Double]()
    private var visitedElements = Set<GraphPathElement>()
    private var evaluatedButNotVisitedElements = Set<GraphPathElement>()

    private init(graph: Graph) {
        self.graph = graph
    }
        
    /// Find and return the shortest path between to element of the graph.
    /// - Parameters:
    ///   - graph: the graph
    ///   - from: the starting element
    ///   - to: the destination element
    /// - Returns: the shortest path or nil if no path found
    static func shortestPath(graph: Graph, from: GraphPathElement, to: GraphPathElement) throws -> GraphPath? {
        return try DijkstraAlgorithm(graph: graph).shortestPath(from: from, to: to)?.reversed
    }
    
    private func shortestPath(from: GraphPathElement, to: GraphPathElement) throws -> GraphPath? {
        distances[from] = 0
        evaluatedButNotVisitedElements.insert(from)
        
        // Visit the graph and assign distances to all the nodes until the `to` node is reached
        try visitGraph(from: from, to: to)
        
        printDistances()
        
        // Now that the distances are assigned, find the shortest path
        return try buildShortestPath(from: from, to: to)
    }
    
    private func printDistances() {
        guard verbose else {
            return
        }
        
        // Now go from to back until from is reached, following the nodes
        // with the smallest distance.
        print("Distances:")
        for item in distances.sorted(by: { $0.key.node.identifier.uuid < $1.key.node.identifier.uuid }) {
            print("\(item.key) = \(item.value)")
        }
    }
        
    // MARK: -
    // MARK: Distances evaluation

    /// Visit the graph from node `from` to node `to`, assigning the shortest distances to each newly discovered nodes.
    /// - Parameters:
    ///   - from: the starting element
    ///   - to: the destination element
    private func visitGraph(from: GraphPathElement, to: GraphPathElement) throws {
        // Do not visit an element that has already been visited
        guard !visitedElements.contains(from) else {
            return
        }
        
        // Remember this element as `visited` and remove it from the list of evaluated
        // elements that have not been visited yet.
        visitedElements.insert(from)
        evaluatedButNotVisitedElements.remove(from)

        // Find out if there is an element reachable from `from`.
        // For example: following "s1' in the next direction, the next element is "t1".
        if let nextElement = nextElement(from: from) {
            guard let fromNodeDistance = distances[from] else {
                // TODO: throw
                fatalError()
            }
            // Compute the new distance to the adjacent node
            // For example: if nextElement is "t1", the distance will be distance(s1) + distance(t1).
            // In effect, the distance is the length of each node (which is actually the length of each
            // block and turnout). The goal is to assign the distance the train will use when following
            // "s1" and "t1" to each of the adjacent nodes of "t1", which are going to be "t2" and "b2".
            let nextElementDistance = fromNodeDistance + nextElement.node.weight
            
            // Assign to all the adjacent nodes of `nextElement` the distance of `nextElement`
            assignDistanceToAdjacentNodesOf(element: nextElement, distance: nextElementDistance)
        }
        
        // Pick the node with the smallest distance
        guard let shortestDistanceElement = evaluatedButNotVisitedElements.sorted(by: { distances[$0]! < distances[$1]! }).first else {
            // This happens when there are no edges out of the `from` node or when all the adjacent nodes of `from` have been evaluated.
            return
        }
                
        print("Smallest distance node is \(shortestDistanceElement) with distance \(distances[shortestDistanceElement]!)")

        // Continue to evaluate the distances recursively, starting now with the element with the shortest distance
        try visitGraph(from: shortestDistanceElement, to: to)
    }
    
    struct NextElement {
        let node: GraphNode
        let entrySocket: SocketId
    }
    
    private func nextElement(from: GraphPathElement) -> NextElement? {
        guard let fromExitSocket = from.exitSocket else {
            // TODO: throw
            fatalError()
        }
        
        guard let edge = graph.edge(from: from.node, socketId: fromExitSocket) else {
            return nil
        }
        
        guard let node = graph.node(for: edge.toNode) else {
            // TODO: throw
            fatalError()
        }
            
        guard let entrySocket = edge.toNodeSocket else {
            // TODO: throw
            fatalError()
        }
        
        return NextElement(node: node, entrySocket: entrySocket)
    }
    
    private func assignDistanceToAdjacentNodesOf(element: NextElement, distance: Double) {
        for exitSocket in element.node.reachableSockets(from: element.entrySocket) {
            let adjacentElement = GraphPathElement.between(element.node, element.entrySocket, exitSocket)
            
            // Skip any element that has been visited before
            guard !visitedElements.contains(adjacentElement) else {
                continue
            }
                            
            // If the adjacent element already has a distance assigned to it and
            // this distance is still the shortest distance, do nothing.
            if let existingDistance = distances[adjacentElement], existingDistance < distance {
                continue
            }
            
            // Otherwise, assign the new distance to the adjacent node
            distances[adjacentElement] = distance
            evaluatedButNotVisitedElements.insert(adjacentElement)
        }
    }
        
    // MARK: -
    // MARK: Building of the shortest path
    
    /// Build and return the shortest path in the graph. This method is called after all the distances are evaluated and it
    /// follows the path in reverse order: it starts with the destination node backwards until it reaches the starting node,
    /// taking at each step the node that has the shortest distance assigned to it.
    /// - Parameters:
    ///   - from: starting element
    ///   - to: destination element
    /// - Returns: the shortest path between the two elements
    private func buildShortestPath(from: GraphPathElement, to: GraphPathElement) throws -> GraphPath? {
        print("Building path from \(from) to \(to)")
        // Note: swap `to` and `from` to build the path in reverse order (needed by the Dijkstra algorithm)
        // and make sure to inverse each element so the entry and exit sockets are also inverted.
        return try buildShortestPath(from: to.inverse, to: from.inverse, path: .init([to]))
    }
    
    private func buildShortestPath(from: GraphPathElement, to: GraphPathElement, path: GraphPath) throws -> GraphPath? {
        // Returns when the `from` element is the same as `to`, which means the destination has been reached.
        if to.isSame(as: from) {
            return path
        }

        // Find the node that follows `from` given its `exitSocket`.
        guard let fromExitSocket = from.exitSocket else {
            // TODO: throw
            fatalError()
        }
        
        guard let edge = graph.edge(from: from.node, socketId: fromExitSocket) else {
            // TODO: throw
            fatalError()
        }
        
        guard let node = graph.node(for: edge.toNode) else {
            throw DijkstraError.nodeNotFound(identifier: edge.toNode)
        }

        var shortestDistance: Double = .infinity
        var shortestDistanceElement: GraphPathElement?

        guard let toNodeSocket = edge.toNodeSocket else {
            // TODO: throw
            fatalError()
        }
        
        // Iterate over all the reachable sockets of `node` and pick
        // the element that has the shortest distance assigned to it.
        for socket in node.reachableSockets(from: toNodeSocket) {
            // Build the element by inverting the entry and exit socket because we are walking the path backwards.
            let element = GraphPathElement.between(node, socket, toNodeSocket)
            
            // Ignore this element if it is already part of the path
            if path.contains(element) {
                continue
            }
            
            guard let distance = distances[element] else {
                // TODO: throw
                fatalError()
            }
            
            print(" * \(element) = \(distance) and shortest distance so far is \(shortestDistance)")
            if distance < shortestDistance {
                shortestDistance = distance
                shortestDistanceElement = element
            }
        }

        // Return nil if there is no shortest distance node found, which can happen for example
        // when the path is trying to pick an element that is already part of the path (to avoid cycle).
        guard let shortestDistanceElement = shortestDistanceElement else {
            return nil
        }

        print("Selected \(shortestDistanceElement.description) with distance \(shortestDistance)")
        // Continue recursively to build the path by taking the newly found shortest distance element.
        // Note: because we are walking the path backwards, we need to inverse the `shortestDistanceElement`
        // in order for the algorithm to continue "backwards".
        return try buildShortestPath(from: shortestDistanceElement.inverse, to: to, path: path.appending(shortestDistanceElement))
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
