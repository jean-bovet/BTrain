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

extension Train.Reservation {
    /// Returns the index of the block corresponding to the block ID.
    ///
    /// The index refers to the block located in the occupied and leading blocks together.
    /// It is used to determine if a block is ahead or behind of another when computing
    /// the position of the train after a feedback has detected the train.
    ///
    ///     Train:  --------------------->
    ///     Blocks: [occupied2][occupied1][leading1][leading(n+1)]
    ///     Index:     1           0         -1         -2
    /// - Parameter blockId: the block id
    /// - Returns: the index of the block id
    func blockIndex(for blockId: Identifier<Block>) -> Int? {
        if let blockIndex = occupied.blocks.firstIndex(where: { $0.id == blockId }) {
            return blockIndex
        }
        if let blockIndex = leading.blocks.firstIndex(where: { $0.id == blockId }) {
            return -1 - blockIndex
        }

        // Note: during manual operation, because no leading blocks are reserved,
        // `nextBlock` contains the block in which the train will enter.
        // Train:  --------------------->
        // Blocks: [occupied2][occupied1][nextBlock]
        // Index:     1           0         -1
        if let nextBlock = nextBlock, nextBlock.id == blockId {
            return -1
        }
        return nil
    }

    // TODO: still used?
    func directionInBlock(for blockId: Identifier<Block>) throws -> Direction? {
        if let block = occupied.blocks.first(where: { $0.id == blockId }) {
            if let ti = block.trainInstance {
                return ti.direction
            } else {
                throw LayoutError.trainNotFoundInBlock(blockId: blockId)
            }
        }
        return nil
    }
}
