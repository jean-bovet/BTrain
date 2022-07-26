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
    
    var blockIds: OrderedSet<Identifier<Block>> {
        blockMap.keys
    }
    
    var blocks: [Block] {
        get {
            blockMap.values.map {
                $0
            }
        }
        set {
            blockMap.removeAll()
            newValue.forEach { blockMap[$0.id] = $0 }
        }
    }

    @discardableResult
    func newBlock(name: String, category: Block.Category) -> Block {
        let block = Block(id: LayoutIdentity.newIdentity(blockMap, prefix: .block), name: name)
        block.category = category
        block.center = .init(x: 100, y: 100)
        blockMap[block.id] = block
        return block
    }

    func duplicate(blockId: Identifier<Block>) {
        guard let block = block(for: blockId) else {
            return
        }
        let nb = newBlock(name: "\(block.name) copy", category: block.category)
        nb.length = block.length
        nb.waitingTime = block.waitingTime
        nb.center = block.center.translatedBy(x: 50, y: 50)
        nb.rotationAngle = block.rotationAngle
        nb.feedbacks = block.feedbacks
        
        nb.entryFeedbackNext = block.entryFeedbackNext
        nb.brakeFeedbackNext = block.brakeFeedbackNext
        nb.stopFeedbackNext = block.stopFeedbackNext
        
        nb.entryFeedbackPrevious = block.entryFeedbackPrevious
        nb.brakeFeedbackPrevious = block.brakeFeedbackPrevious
        nb.stopFeedbackPrevious = block.stopFeedbackPrevious
    }
    
    func remove(blockID: Identifier<Block>) {
        transitions.removeAll { transition in
            transition.a.block == blockID ||
                    transition.b.block == blockID
        }

        blockMap.removeValue(forKey: blockID)

        trains.forEach { train in
            if train.blockId == blockID {
                train.blockId = nil
            }
        }
    }
    
    func block(at index: Int) -> Block {
        blockMap.values[index]
    }
    
    func block(for blockId: Identifier<Block>?) -> Block? {
        if let blockId = blockId {
            return blockMap[blockId]
        } else {
            return nil
        }
    }
    
    func block(for trainId: Identifier<Train>) -> Block? {
        blockMap.first(where: { $0.value.trainInstance?.trainId == trainId })?.value
    }
    
    func sortBlocks() {
        blockMap.sort {
            $0.value.name < $1.value.name
        }
    }
    
    func assign(_ block: Block, _ feedbacks: [Feedback]) {
        block.assign(feedbacks.map { $0.id })
        for feedback in feedbacks {
            if !self.feedbacks.contains(feedback) {
                self.feedbacks.append(feedback)
            }
        }
    }

    func add(_ blocks: [Block]) {
        for block in blocks {
            self.blockMap[block.id] = block
        }
    }
        
    func currentBlock(train: Train) -> Block? {
        if let blockId = train.blockId {
            return block(for: blockId)
        } else {
            return nil
        }
    }
    
    func atEndOfBlock(train: Train) throws -> Bool {
        if let currentBlock = currentBlock(train: train) {
            guard let ti = currentBlock.trainInstance else {
                throw LayoutError.trainNotFoundInBlock(blockId: currentBlock.id)
            }
            if ti.direction == .next {
                return train.position == currentBlock.feedbacks.count
            } else {
                return train.position == 0
            }
        } else {
            return false
        }
    }

}
