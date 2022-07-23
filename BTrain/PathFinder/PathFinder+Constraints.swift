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

extension PathFinder {
    
    /// The constraints to apply to the path finder algorithm
    struct Constraints {
        
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
        
        let layout: Layout
        let train: Train
        let reservedBlockBehavior: ReservedBlockBehavior
        
        /// True if the constraints should be relaxed (that is, not applied), false otherwise.
        let relaxed: Bool
        
        /// True if the algorithm is resolving a path, false otherwise. This flag acts on a specific
        /// condition when including a node (see below)
        let resolving: Bool

        /// Returns true if the `node` should be included in the path.
        ///
        /// If false, the algorithm backtracks to the previous node and finds
        /// an alternative edge if possible.
        ///
        /// - Parameters:
        ///   - node: the node to evaluate
        ///   - currentPath: the current path that has been found so far
        ///   - to: the optional destination element
        /// - Returns: true if `node` should be included in the path, false otherwise.
        func shouldInclude(node: GraphNode, currentPath: GraphPath, to: GraphPathElement?) -> Bool {
            if let to = to, node is Block && to.node is Block && node.identifier.uuid != to.node.identifier.uuid, resolving {
                // Backtrack if the first block is not the destination node.
                // Note: this is currently a limitation of the resolver in which it is expected that a route
                // defines all the blocks in the route. The resolver just resolves the turnouts between two
                // blocks but not an arbitrary long route with turnouts and blocks, which can be expensive
                // to traverse until we have a breadth-first algorithm implementation to search for the shortest
                // path between one block to another (arbitrary far away) block.
                return false
            }

            if relaxed {
                return true
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
