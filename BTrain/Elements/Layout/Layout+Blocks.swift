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

extension Layout {
    @discardableResult
    func newBlock(name: String, category: Block.Category) -> Block {
        let block = Block(id: LayoutIdentity.newIdentity(blocks.elements, prefix: .block), name: name)
        block.category = category
        block.center = .init(x: 100, y: 100)
        blocks.add(block)
        return block
    }

    @discardableResult
    func duplicate(block: Block) -> Block {
        let nb = Block(id: LayoutIdentity.newIdentity(blocks.elements, prefix: .block), name: "\(name) copy")

        nb.length = block.length
        nb.waitingTime = block.waitingTime
        nb.center = block.center
        nb.rotationAngle = block.rotationAngle
        nb.feedbacks = block.feedbacks

        nb.entryFeedbackNext = block.entryFeedbackNext
        nb.brakeFeedbackNext = block.brakeFeedbackNext
        nb.stopFeedbackNext = block.stopFeedbackNext

        nb.entryFeedbackPrevious = block.entryFeedbackPrevious
        nb.brakeFeedbackPrevious = block.brakeFeedbackPrevious
        nb.stopFeedbackPrevious = block.stopFeedbackPrevious

        blocks.add(nb)

        return nb
    }

    func remove(blockID: Identifier<Block>) {
        transitions.elements.removeAll { transition in
            transition.a.block == blockID ||
                transition.b.block == blockID
        }

        blocks.remove(blockID)

        trains.elements.forEach { train in
            if train.blockId == blockID {
                train.blockId = nil
            }
        }
    }

    func block(for trainId: Identifier<Train>) -> Block? {
        blocks.elements.first(where: { $0.trainInstance?.trainId == trainId })
    }

    func assign(_ block: Block, _ feedbacks: [Feedback]) {
        block.assign(feedbacks.map { $0.id })
        for feedback in feedbacks {
            self.feedbacks.add(feedback)
        }
    }

    // TODO: is that the right way to use the currentBlock?
    func atEndOfBlock(train: Train) throws -> Bool {
        guard let currentBlock = blocks[train.blockId] else {
            return false
        }
        return try train.atEndOfBlock(block: currentBlock)
    }
}
