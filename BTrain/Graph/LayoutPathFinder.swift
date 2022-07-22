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

// This class finds path from one block to another in the layout, taking
// into consideration various constraints, such as disabled block, reserved blocks, etc.
final class LayoutPathFinder {    
        
    let constraints: LayoutConstraints
    
    struct Settings {
        // If true, emits debug logs to help troubleshoot the algorithm
        let verbose: Bool
        
        // If true, edges out of a node are chosen at random
        let random: Bool
        
        // Maximum number of elements in a path before giving up.
        // This value should be at least the number of nodes in the graph.
        let overflow: Int
    }
    
    let settings: Settings
            
    enum ReservedBlockBehavior {
        // Avoid all reserved blocks (that is, avoid any block
        // that is reserved for another train).
        case avoidReserved
        
        // Ignore all reserved blocks (that is,
        // take them into account even if they are
        // reserved for another train).
        case ignoreReserved
        
        // Avoid the first reserved block encountered,
        // then ignore all the others reserved blocks.
        case avoidFirstReservedBlock
    }
    
    init(constraints: LayoutConstraints, settings: Settings) {
        self.constraints = constraints
        self.settings = settings
    }
    
    convenience init(layout: Layout, train: Train, reservedBlockBehavior: ReservedBlockBehavior, settings: Settings) {
        self.init(constraints: LayoutConstraints(layout: layout, train: train, reservedBlockBehavior: reservedBlockBehavior, relaxed: false),
                  settings: settings)
    }
    
    /// Returns the path between two nodes in a graph, given the specified constraints and context.
    ///
    /// - Parameters:
    ///   - graph: the graph
    ///   - from: the starting node
    ///   - to: the destination node or nil to find the next destination block (as defined by ``LayoutPathFinder.LayoutConstraints/reachedDestination(node:to:)``
    ///   - constraints: the constraints to apply
    /// - Returns: a path or nil if no path is found
    func path(graph: Graph, from: GraphNode, to: GraphNode?, constraints: LayoutPathFinder.LayoutConstraints) -> GraphPath? {
        for socketId in shuffled(from.sockets(constraints)) {
            if let to = to {
                for toSocketId in shuffled(to.sockets(constraints)) {
                    if let steps = path(graph: graph, from: .starting(from, socketId), to: .ending(to, toSocketId), currentPath: GraphPath([.starting(from, socketId)]), constraints: constraints) {
                        return steps
                    }
                }
            } else {
                if let steps = path(graph: graph, from: .starting(from, socketId), to: nil, currentPath: GraphPath([.starting(from, socketId)]), constraints: constraints) {
                    return steps
                }
            }
        }
        return nil
    }

    /// Returns the path between two path elements in a graph, given the specified constraints and context.
    ///
    /// A path element is a node with a specific entry and exit socket defined.
    ///
    /// - Parameters:
    ///   - graph: the graph
    ///   - from: the starting element
    ///   - to: the destination element or nil to find the next destination block (as defined by ``LayoutPathFinder.LayoutConstraints/reachedDestination(node:to:)``
    ///   - constraints: the constraints to apply
    /// - Returns: a path or nil if no path is found
    func path(graph: Graph, from: GraphPathElement, to: GraphPathElement?, constraints: LayoutPathFinder.LayoutConstraints) -> GraphPath? {
        path(graph: graph, from: from, to: to, currentPath: GraphPath([from]), constraints: constraints)
    }

    /// Returns the shortest path between two path elements in a graph, given the specified constraints and context.
    ///
    /// A path element is a node with a specific entry and exit socket defined.
    /// - Parameters:
    ///   - graph: the graph
    ///   - from: the starting element
    ///   - to: the destination element
    ///   - constraints: the constraints to apply
    /// - Returns: the shortest path or nil if no path is found
    func shortestPath(graph: Graph, from: GraphPathElement, to: GraphPathElement, constraints: LayoutPathFinder.LayoutConstraints) throws -> GraphPath? {
        try GraphShortestPathFinder.shortestPath(graph: graph, from: from, to: to, constraints: constraints, verbose: settings.verbose)
    }
    
    func resolve(graph: Graph, _ path: UnresolvedGraphPath, constraints: LayoutPathFinder.LayoutConstraints, errors: inout [GraphPathFinderResolver.ResolverError]) -> GraphPath? {
        let resolver = GraphPathFinderResolver(gpf: self)
        return resolver.resolve(graph: graph, path, constraints: constraints, errors: &errors)
    }
    
    private func path(graph: Graph, from: GraphPathElement, to: GraphPathElement?, currentPath: GraphPath, constraints: LayoutPathFinder.LayoutConstraints) -> GraphPath? {
        if settings.verbose {
            if let to = to {
                debug("From \(from) to \(to): \(currentPath.toStrings)")
            } else {
                debug("From \(from): \(currentPath.toStrings)")
            }
        }
        
        guard currentPath.count < settings.overflow else {
            if settings.verbose {
                debug("Current path is overflowing, backtracking")
            }
            return nil
        }
        
        guard from != to else {
            return currentPath
        }
        
        guard let exitSocket = from.exitSocket else {
            if settings.verbose {
                debug("No exit socket defined for \(from.node)")
            }
            return nil
        }
        
        guard let edge = graph.edge(from: from.node, socketId: exitSocket, constraints: constraints) else {
            if settings.verbose {
                debug("No edge found from \(from.node) and socket \(exitSocket)")
            }
            return nil
        }
        
        guard let node = graph.node(for: edge.toNode, constraints: constraints) else {
            if settings.verbose {
                debug("No destination node found in graph for \(edge.toNode)")
            }
            return nil
        }
        
        guard let entrySocketId = edge.toNodeSocket else {
            if settings.verbose {
                debug("No entry socket for destination node \(node) in graph")
            }
            return nil
        }
                        
        if !constraints.shouldInclude(node: node, currentPath: currentPath, to: to) {
            debug("Node \(node) should not be included, backtracking")
            return nil
        }
                
        let endingElement = GraphPathElement.ending(node, entrySocketId)

        if let to = to, to.isSame(as: endingElement) {
            // If the destination node is specified and is the same as the current element,
            // we have reached the destination node
            return currentPath.appending(endingElement)
        } else if constraints.reachedDestination(node: node, to: to) {
            return currentPath.appending(endingElement)
        }

        // We haven't reached the destination node, keep going forward
        // by exploring all the possible exit sockets from `node`
        let exitSockets = node.reachableSockets(from: entrySocketId, constraints)
        for exitSocket in shuffled(exitSockets) {
            let betweenElement = GraphPathElement.between(node, entrySocketId, exitSocket)
            
            guard !currentPath.contains(betweenElement) else {
                if settings.verbose {
                    debug("Node \(betweenElement) is already part of the path, backtracking")
                }
                // Continue to the next socket as this socket (in combination with the entrySocketId)
                // has already been used in the path
                continue
            }
            
            if let path = path(graph: graph, from: betweenElement, to: to,
                               currentPath: currentPath.appending(.between(node, entrySocketId, exitSocket)),
                               constraints: constraints) {
                return path
            }
        }

        return nil
    }

    private func debug(_ msg: String) {
        if settings.verbose {
            BTLogger.debug(msg)
        }
    }
    
    private func shuffled(_ sockets: [SocketId]) -> [SocketId] {
        if settings.random {
            return sockets.shuffled()
        } else {
            return sockets
        }
    }
    
    // TODO: make it final
    class LayoutConstraints {
        
        let layout: Layout?
        let train: Train?
        let reservedBlockBehavior: ReservedBlockBehavior?
        let relaxed: Bool

        init(layout: Layout?, train: Train?, reservedBlockBehavior: ReservedBlockBehavior?, relaxed: Bool) {
            self.layout = layout
            self.train = train
            self.reservedBlockBehavior = reservedBlockBehavior
            self.relaxed = relaxed
        }

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
        func shouldInclude(node: GraphNode, currentPath: GraphPath, to: GraphPathElement?) -> Bool {
            if relaxed {
                return true
            }
            
            guard let layout = layout else {
                return false
            }

            guard let train = train else {
                return false
            }

            guard let reservedBlockBehavior = reservedBlockBehavior else {
                return false
            }
            
            if let block = layout.block(node) {
                guard block.enabled else {
                    return false
                }
                                
                if let reserved = block.reservation, reserved.trainId != train.id {
                    switch reservedBlockBehavior {
                    case .avoidReserved:
                        return false
                        
                    case .ignoreReserved:
                        break
                        
                    case .avoidFirstReservedBlock:
                        // Count how many blocks there is in the current path, ignoring the first block which
                        // is the starting block. The "first reserved block" means the first block after the starting block.
                        if currentPath.numberOfBlocksIgnoringStartingBlock == 0 {
                            // If there are zero blocks in the path, it means that `node` is the first block,
                            // in which case we need to avoid it because it is reserved.
                            return false
                        }
                        break
                    }
                }
                
                if train.blocksToAvoid.contains(where: { $0.blockId == block.id }) {
                    return false
                }
                
                return true
            }
            
            if let turnout = layout.turnout(node) {
                guard turnout.enabled else {
                    return false
                }
                
                if let reserved = turnout.reserved, reserved.train != train.id {
                    switch reservedBlockBehavior {
                    case .avoidReserved:
                        return false
                        
                    case .ignoreReserved:
                        break
                        
                    case .avoidFirstReservedBlock:
                        // Count how many blocks there is in the current path, ignoring the first block which
                        // is the starting block. The "first reserved block" means the first block after the starting block.
                        if currentPath.numberOfBlocksIgnoringStartingBlock == 0 {
                            return false
                        }
                        break
                    }
                }
                
                if train.turnoutsToAvoid.contains(where: { $0.turnoutId == turnout.id }) {
                    return false
                }
                
                return true
            }
            
            return true
        }
        
        /// Returns true if the specified node is the destination node of the path.
        /// - Parameters:
        ///   - node: the node to evaluate
        ///   - to: the optional destination block. If nil, the constraints should evalute if node is a destination or not (ie is it a station?)
        /// - Returns: true if `node` is a destination, false otherwise
        func reachedDestination(node: GraphNode, to: GraphPathElement?) -> Bool {
            if relaxed {
                return false
            }
            
            guard let layout = layout else {
                return false
            }

            if let block = layout.block(node), to == nil {
                // If no destination element is specified, we stop at the first station block
                return block.category == .station
            }
            return false
        }
    }
}

extension GraphPath {
    
    var numberOfBlocksIgnoringStartingBlock: Int {
        elements
            .dropFirst() // Remove the starting block
            .filter({ $0.node is Block }) // Filter out any element that is not a block
            .count // Count the number of blocks
    }
}
