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

class LayoutPathFinder: GraphPathFinder {
        
    let layout: Layout
    let train: Train
    let reservedBlockBehavior: PathFinder.Settings.ReservedBlockBehavior

    init(layout: Layout, train: Train, reservedBlockBehavior: PathFinder.Settings.ReservedBlockBehavior = .ignoreReserved) {
        self.layout = layout
        self.train = train
        self.reservedBlockBehavior = reservedBlockBehavior
    }
    
    override func shouldInclude(node: GraphNode, currentPath: GraphPath, to: GraphPathElement?) -> Bool {
        if let block = layout.block(for: Identifier<Block>(uuid: node.identifier)) {
            guard block.enabled else {
                return false
            }
            
            if let reserved = block.reserved {
                let reservedForAnotherTrain = reserved.trainId != train.id
                
                switch reservedBlockBehavior {
                case .avoidReserved:
                    if reservedForAnotherTrain {
                        return false
                    }

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
        
        if let turnout = layout.turnout(for: Identifier<Turnout>(uuid: node.identifier)) {
            guard turnout.enabled else {
                return false
            }
            
            if let reserved = turnout.reserved {
                let reservedForAnotherTrain = reserved.train != train.id
                
                switch reservedBlockBehavior {
                case .avoidReserved:
                    if reservedForAnotherTrain {
                        return false
                    }

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

        return super.shouldInclude(node: node, currentPath: currentPath, to: to)
    }
    
    override func reachedDestination(node: GraphNode, to: GraphPathElement?) -> Bool {
        if let block = layout.block(for: Identifier<Block>(uuid: node.identifier)), to == nil {
            // If no destination element is specified, we stop at the first station block
            return block.category == .station
        } else {
            return super.reachedDestination(node: node, to: to)
        }
    }

}

extension Array where Element == GraphPathElement {
    
    var numberOfBlocksIgnoringStartingBlock: Int {
        dropFirst() // Remove the starting block
            .filter({ $0.node is Block }) // Filter out any element that is not a block
            .count // Count the number of blocks
    }
}
