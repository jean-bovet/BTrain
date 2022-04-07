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

final class LayoutPathFinder: GraphPathFinder {
        
    let layout: Layout
    let train: Train
    let reservedBlockBehavior: PathFinder.Settings.ReservedBlockBehavior

    init(layout: Layout, train: Train, reservedBlockBehavior: PathFinder.Settings.ReservedBlockBehavior = .ignoreReserved) {
        self.layout = layout
        self.train = train
        self.reservedBlockBehavior = reservedBlockBehavior
    }
    
    override func shouldInclude(node: GraphNode, currentPath: GraphPath) -> Bool {
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
                    // is the starting block. The "first reserved block" means the first block after
                    // the starting block.
                    if currentPath.dropFirst().filter({ $0.node is Block }).count == 0 {
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
            
            if let reserved = turnout.reserved, reserved.train != train.id {
                return false
            }
            
            if train.turnoutsToAvoid.contains(where: { $0.turnoutId == turnout.id }) {
                return false
            }

            return true
        }

        return super.shouldInclude(node: node, currentPath: currentPath)
    }
    
    override func reachedDestination(node: GraphNode) -> Bool {
        if let block = layout.block(for: Identifier<Block>(uuid: node.identifier)) {
            return block.category == .station
        } else {
            return super.reachedDestination(node: node)
        }
    }

}
