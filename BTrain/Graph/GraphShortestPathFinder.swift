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
import OrderedCollections

/// This class implements the Dijkstra algorithm that finds the shortest path in a graph.
///
/// The algorithm is specifically crafted to take into account the fact that node in a graph
/// represents block and turnout that have a direction of travel. This means that a node alone
/// is not enough to evaluate the distance but rather a node **and** its direction of travel is the key
/// that is used to keep track of the distances.
/// See [Dijkstra on Wikipedia](https://en.wikipedia.org/wiki/Dijkstra%27s_algorithm)
final class GraphShortestPathFinder {

    // TODO: implement same constraints as GraphPathFinder
    // TODO: implement same overflow check
    
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

    enum PathFinderError: Error {
        case missingExitSocket(from: GraphPathElement)
        case distanceNotFound(`for`: GraphPathElement)
        case pathNotFound(`for`: GraphPathElement)
        case nodeNotFound(identifier: GraphElementIdentifier)
        case destinationSocketNotFound(`for`: GraphEdge)
        case edgeNotFound(`for`: GraphNode, socketId: SocketId)
        case invalidElement(_ element: GraphPathElement)
    }
    
    private let graph: Graph    
    private let verbose: Bool
        
    /// Map of the distances between each element of the graph and the starting element.
    ///
    /// An element is identifier by its node and its entry and exit sockets. For example:
    /// - 0:s1:1 indicates the block s1 in the direction of travel "next".
    /// - 1:s1:0 indicates the block s1 in the direction of travel "previous".
    /// - 0:t1:2 indicates the turnout t1 with the exit socket (2) indicating the right-branch.
    private var distances = [GraphPathElement:Double]()
    
    /// Map of the path from the starting node to the element. This is used to build the shortest path
    /// as the algorithm visits all the nodes. Each time a node is visited with a distance shorter than
    /// any previous distance assigned to the node, the path is set for that node. The next time the
    /// algorithm picks that node to continue the evaluation, it knows which path to use.
    private var paths = [GraphPathElement:GraphPath]()

    /// Set of elements that have been already visited.
    private var visitedElements = Set<GraphPathElement>()
        
    /// Set of elements that have been evaluated (that is, a distance has been computed for that element)
    /// but have not yet been visited.
    ///
    /// Note: use `OrderedSet` to ensure stable outcome of the algorithm.
    private var evaluatedButNotVisitedElements = OrderedSet<GraphPathElement>()
    
    /// The shortest path found so far. This variable is updated each time the destination node is reached
    /// with a distance that's shorter than the previous one.
    /// nil if the algorithm is not able to reach the destination node.
    private var shortestPath: GraphPath?
    
    private init(graph: Graph, verbose: Bool) {
        self.graph = graph
        self.verbose = verbose
    }
        
    /// Find and return the shortest path between two element of the graph.
    /// - Parameters:
    ///   - graph: the graph
    ///   - from: the starting element
    ///   - to: the destination element
    ///   - constraints: the constraints to apply to the graph
    /// - Returns: the shortest path or nil if no path found
    static func shortestPath(graph: Graph, from: GraphPathElement, to: GraphPathElement, constraints: GraphPathFinderConstraints = GraphPathFinder.DefaultConstraints(), verbose: Bool) throws -> GraphPath? {
        return try GraphShortestPathFinder(graph: graph, verbose: verbose).shortestPath(from: from, to: to, constraints: constraints)
    }
    
    // For example:
    // from = 0:s1:1 (which means, block "s1" with entry socket 0 and exit socket 1, indicating a natural direction of "next" in the block)
    // to = 0:s2:1
    private func shortestPath(from: GraphPathElement, to: GraphPathElement, constraints: GraphPathFinderConstraints) throws -> GraphPath? {
        // Set the distance of the starting element `from` to 0 as well as an empty path.
        setDistance(0, to: from, path: GraphPath([]))
        
        // Visit the graph and assign distances to all the nodes until the `to` node is reached
        try visitGraph(from: from, to: to, currentPath: GraphPath([from]), constraints: constraints)
        
        printDistances()
                
        return shortestPath
    }
    
    private func setDistance(_ distance: Double, to: GraphPathElement, path: GraphPath) {
        distances[to] = distance
        paths[to] = path
        evaluatedButNotVisitedElements.append(to)
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
    private func visitGraph(from: GraphPathElement, to: GraphPathElement, currentPath: GraphPath, constraints: GraphPathFinderConstraints) throws {
        // Do not visit an element that has already been visited
        guard !visitedElements.contains(from) else {
            return
        }
                
        // Remember this element as `visited`
        visitedElements.insert(from)
        
        // And remove it from the list of evaluated elements that have not been visited.
        evaluatedButNotVisitedElements.remove(from)

        // Find out if there is an element reachable from `from`.
        // For example: with from = 0:s1:1, the next element is "t1" with entry socket 0.
        if let nextElement = try nextElement(of: from) {
            // Retrieve the distance of the `from` node.
            guard let fromNodeDistance = distances[from] else {
                throw PathFinderError.distanceNotFound(for: from)
            }
            
            // Compute the new distance to the adjacent node
            // For example: if nextElement is "t1", the distance will be distance(s1) + distance(t1).
            // In effect, the distance is the length of each node (which is actually the length of each
            // block and turnout). The goal is to assign the distance the train will use when following
            // "s1" and "t1" to each of the adjacent nodes of "t1", which are going to be "t2" and "b2".
            let nextElementDistance = fromNodeDistance + nextElement.node.weight
            
            // Assign to all the adjacent nodes of `nextElement` the distance of `nextElement`
            assignDistanceToPathConfigurationsOf(element: nextElement, to: to, distance: nextElementDistance, path: currentPath, constraints: constraints)
        }
        
        // Now, from all the elements that have been evaluated, that is, assigned a distance, pick the element
        // that has the shortest distance. In our example, from s1, we evaluated "0:t1:1" and "0:t1:2".
        guard let shortestDistanceElement = evaluatedButNotVisitedElements.sorted(by: { distances[$0]! < distances[$1]! }).first else {
            // This happens when there are no edges out of the `from` node or when all the adjacent nodes of `from` have been evaluated.
            return
        }
                
        if verbose {
            print("Shortest distance element is \(shortestDistanceElement) with distance \(distances[shortestDistanceElement]!)")
        }

        // Retrieve the shortest path for the shortest distance element.
        // It should exist because we computed it in `assignDistanceToPathConfigurationsOf`.
        guard let path = paths[shortestDistanceElement] else {
            throw PathFinderError.pathNotFound(for: shortestDistanceElement)
        }
        
        // Continue to evaluate the distances recursively, starting now with the element with the shortest distance
        try visitGraph(from: shortestDistanceElement, to: to, currentPath: path, constraints: constraints)
    }
    
    struct NextElement {
        let node: GraphNode
        let entrySocket: SocketId
    }
    
    /// Returns the element following the specified `element`. There is always zero or one element following
    /// an element (zero in case of a siding block).
    private func nextElement(of element: GraphPathElement) throws -> NextElement? {
        guard let fromExitSocket = element.exitSocket else {
            throw PathFinderError.missingExitSocket(from: element)
        }
        
        guard let edge = graph.edge(from: element.node, socketId: fromExitSocket) else {
            return nil
        }
        
        guard let node = graph.node(for: edge.toNode) else {
            throw PathFinderError.nodeNotFound(identifier: edge.toNode)
        }
            
        guard let entrySocket = edge.toNodeSocket else {
            throw PathFinderError.destinationSocketNotFound(for: edge)
        }
        
        return NextElement(node: node, entrySocket: entrySocket)
    }
    
    /// Assign the distance computed for an element to all the paths that this element can produce to the next element(s).
    ///
    /// For example, starting our example with element "0:s1:1", the next element `element` is "t1", which is a turnout. This turnout
    /// can lead to two different elements, based on its configuration:
    /// - configuration "0:t1:1" leads to "t2"
    /// - configuration "0:t1:2" leads to "b2".
    ///
    /// We need to assign the distance computed so far to each of these configurations. Later on, the algorithm will pick the node configuration
    /// with the shortest distance and will start again from there, to either "t2" or "b2.
    ///
    /// - Parameters:
    ///   - element: the element whose configurations should have a distance assigned to
    ///   - to: the destination node
    ///   - distance: the shortest distance up to `element`
    ///   - path: the current shortest path
    ///   - constraints: the constraints
    private func assignDistanceToPathConfigurationsOf(element: NextElement, to: GraphPathElement, distance: Double, path: GraphPath, constraints: GraphPathFinderConstraints) {
        for exitSocket in element.node.reachableSockets(from: element.entrySocket) {
            // Build up a particular element configuration using the specified exitSocket.
            // For example, starting with element "0:t1", we will have:
            // 0:t1:1 and 0:t1:2
            let elementConfiguration = GraphPathElement.between(element.node, element.entrySocket, exitSocket)
            
            // Skip any element that has been visited before
            guard !visitedElements.contains(elementConfiguration) else {
                if elementConfiguration == to && shortestPath == nil {
                    shortestPath = path.appending(elementConfiguration)
                }
                continue
            }

            // Apply any constraints to this element, in order to skip it if necessary
            if !constraints.shouldInclude(node: elementConfiguration.node, currentPath: path, to: to) {
                BTLogger.debug("Element \(elementConfiguration) should not be included, will not include it")
                return
            }

            // If this element already has a distance assigned to it and this distance is still the shortest distance,
            // do nothing and continue to the next configuration possible.
            if let existingDistance = distances[elementConfiguration], existingDistance <= distance {
                continue
            }
                                        
            // Otherwise, assign the new distance to the element
            setDistance(distance, to: elementConfiguration, path: path.appending(elementConfiguration))
            
            // If the element is also the destination element, remember the shortest path
            if elementConfiguration == to {
                shortestPath = path.appending(elementConfiguration)
            }
        }
    }    
    
}

extension GraphShortestPathFinder.PathFinderError: LocalizedError {
    
    var errorDescription: String? {
        switch self {
        case .missingExitSocket(from: let from):
            return "Missing exit socket from \(from)"
        case .distanceNotFound(for: let element):
            return "Distance not found for \(element)"
        case .pathNotFound(for: let element):
            return "Path not found for \(element)"
        case .nodeNotFound(identifier: let identifier):
            return "Node not found for \(identifier)"
        case .destinationSocketNotFound(for: let element):
            return "Destination socketnot found for \(element)"
        case .edgeNotFound(for: let node, socketId: let socketId):
            return "Edge not found for \(node) and socket \(socketId)"
        case .invalidElement(element: let element):
            return "Invalid element \(element)"
        }
    }
}

extension GraphPathElement {
    
    func inverse() throws -> GraphPathElement {
        if let entrySocket = entrySocket, let exitSocket = exitSocket {
            return .between(node, exitSocket, entrySocket)
        } else if let entrySocket = entrySocket {
            return .starting(node, entrySocket)
        } else if let exitSocket = exitSocket {
            return .ending(node, exitSocket)
        } else {
            throw GraphShortestPathFinder.PathFinderError.invalidElement(self)
        }
    }
}
