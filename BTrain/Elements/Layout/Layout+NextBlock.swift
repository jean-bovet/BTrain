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

extension Layout {
    /// The feedback that is indicating a specific train is entering a block.
    struct EntryFeedback {
        /// The block the train is entering when the ``feedback`` is triggered
        let block: Block

        /// The feedback that will be triggered by the train entering ``block``
        let feedback: Feedback
        
        /// The index of the feedback inside ``block``
        let index: Int
        
        /// The direction of travel of the train entering ``block``, relative to ``block``.
        let direction: Direction
    }

    /// Returns the entry feedback that is expected to be triggered when the train enters the next block.
    ///
    /// The next block is computed by taking into account the direction of travel of the train and the ``strictRouteFeedbackStrategy`` settings.
    ///
    /// - Parameter train: the train
    /// - Returns: the entry feedback or nil if no valid entry feedback is found
    func entryFeedback(for train: Train) throws -> EntryFeedback? {
        guard let currentBlock = currentBlock(train: train) else {
            return nil
        }

        let nextBlock: Block

        if train.scheduling == .unmanaged {
            guard let nb = try nextValidBlockForLocomotive(from: currentBlock, train: train) else {
                return nil
            }
            nextBlock = nb
        } else {
            // Regardless of the direction of traveling of the train, we always rely on the
            // first leading block to be the one that the train will enter next.
            guard let nb = train.leading.blocks.first else {
                return nil
            }
            nextBlock = nb

            // Strict route strategy requires the train to be at the end of the block
            // before moving to the next block.
            if strictRouteFeedbackStrategy {
                if try atEndOfBlock(train: train) == false {
                    return nil
                }
            }
        }

        // Find out which feedback is going to be used to detect the train entering
        // the `nextBlock` block.
        return try entryFeedback(from: currentBlock, to: nextBlock)
    }

    /// Returns the feedback used to detect when a train enters a block.
    ///
    /// - Parameters:
    ///   - fromBlock: the current block
    ///   - nextBlock: the next block that the train is about to enter
    /// - Returns: the feedback and the direction of travel of the train inside the ``nextBlock``
    func entryFeedback(from fromBlock: Block, to nextBlock: Block) throws -> Layout.EntryFeedback? {
        guard let direction = fromBlock.trainInstance?.direction else {
            throw LayoutError.trainNotFoundInBlock(blockId: fromBlock.id)
        }

        // The direction in which to enter the next block can be determined
        // by the reservation of the block, if available. Otherwise,
        // the algorithm will try both directions.
        let nextDirection = nextBlock.reservation?.direction

        let transitions = try transitions(from: LayoutVector(block: fromBlock, direction: direction),
                                          to: LayoutVector(block: nextBlock, direction: nextDirection))

        // Note: grab the last transition which is the one that leads to `nextBlock`.
        guard let lastTransition = transitions.last else {
            // It is possible that there are no transitions between these two blocks, for example,
            // when moving between two blocks that requires the train to move backwards but the
            // train has not yet changed direction. Instead of throwing an error, we simply return nil.
            return nil
        }

        // Determine if the train is moving in the "natural" direction
        // inside the next block, that is, entering from the "previous" side
        // (and exiting in the "next" side). This will help determine
        // which feedback to monitor on that next block.
        guard let blockId = lastTransition.b.block, blockId == nextBlock.id else {
            throw LayoutError.lastTransitionToBlock(transition: lastTransition.id, blockId: nextBlock.id)
        }

        let nextBlockDirectionOfTravel: Direction = lastTransition.b.socketId == Block.previousSocket ? .next : .previous

        // Now return the appropriate feedback depending on the direction
        // of travel of the train into the next block.
        let entryFeedbackId = nextBlock.entryFeedback(for: nextBlockDirectionOfTravel)

        // Determine the index of the feedback within the next block
        guard let index = nextBlock.feedbacks.firstIndex(where: { $0.feedbackId == entryFeedbackId }) else {
            return nil
        }
        
        if let entryFeedback = feedbacks[entryFeedbackId] {
            return Layout.EntryFeedback(block: nextBlock, feedback: entryFeedback, index: index, direction: nextBlockDirectionOfTravel)
        } else {
            return nil
        }
    }
}
