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

/// Defines the methods of a generic path finder in a graph.
protocol GraphPathFinding {
    
    /// Returns the path between two nodes in a graph, given the specified constraints and context.
    ///
    /// - Parameters:
    ///   - graph: the graph
    ///   - from: the starting node
    ///   - to: the destination node or nil to find the next destination block (as defined by ``GraphPathFinderConstraints/reachedDestination(node:to:)``
    ///   - constraints: the constraints to apply
    ///   - context: the context to consider
    /// - Returns: a path or nil if no path is found
    func path(graph: Graph, from: GraphNode, to: GraphNode?, constraints: GraphPathFinderConstraints, context: GraphPathFinderContext) -> GraphPath?
    
    /// Returns the path between two path elements in a graph, given the specified constraints and context.
    ///
    /// A path element is a node with a specific entry and exit socket defined.
    ///
    /// - Parameters:
    ///   - graph: the graph
    ///   - from: the starting element
    ///   - to: the destination element or nil to find the next destination block (as defined by ``GraphPathFinderConstraints/reachedDestination(node:to:)``
    ///   - constraints: the constraints to apply
    ///   - context: the context to consider
    /// - Returns: a path or nil if no path is found
    func path(graph: Graph, from: GraphPathElement, to: GraphPathElement?, constraints: GraphPathFinderConstraints, context: GraphPathFinderContext) -> GraphPath?

    /// Returns the shortest path between two path elements in a graph, given the specified constraints and context.
    ///
    /// A path element is a node with a specific entry and exit socket defined.
    /// - Parameters:
    ///   - graph: the graph
    ///   - from: the starting element
    ///   - to: the destination element
    ///   - constraints: the constraints to apply
    ///   - context: the context to consider
    /// - Returns: the shortest path or nil if no path is found
    func shortestPath(graph: Graph, from: GraphPathElement, to: GraphPathElement, constraints: GraphPathFinderConstraints, context: GraphPathFinderContext) throws -> GraphPath?

}

/// Defines the context when finding a path in a graph.
///
/// The caller of the path find algorithm provides a subclass or a struct for the context
/// which will be passed in the constrains and resolving functions. A context contains,
/// for example, the current train and layout.
protocol GraphPathFinderContext {
    
}

/// Defines the constraints when finding a path in a graph.
protocol GraphPathFinderConstraints {
    
    /// Returns true if the `node` should be included in the path.
    ///
    /// If false, the algorithm backtracks to the previous node and finds
    /// an alternative edge if possible.
    ///
    /// - Parameters:
    ///   - node: the node to evaluate
    ///   - currentPath: the current path that has been found so far
    ///   - to: the optional destination element
    ///   - context: the context
    /// - Returns: true if `node` should be included in the path, false otherwise.
    func shouldInclude(node: GraphNode, currentPath: GraphPath, to: GraphPathElement?, context: GraphPathFinderContext) -> Bool
    
    /// Returns true if the specified node is the destination node of the path.
    /// - Parameters:
    ///   - node: the node to evaluate
    ///   - to: the optional destination block. If nil, the constraints should evalute if node is a destination or not (ie is it a station?)
    /// - Returns: true if `node` is a destination, false otherwise
    func reachedDestination(node: GraphNode, to: GraphPathElement?) -> Bool

}
