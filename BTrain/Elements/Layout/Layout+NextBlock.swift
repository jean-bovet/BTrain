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
        
        /// The direction of travel of the train entering ``block``, relative to ``block``.
        let direction: Direction
    }
    
    /// Returns a structure describing the feedback that will be triggered by the train is entering a new block.
    ///
    /// - Parameter train: the train
    /// - Returns: a structure describing the entry feedback and its associated parameters
    func entryFeedback(for train: Train) throws -> EntryFeedback? {
        guard let currentBlock = currentBlock(train: train) else {
            return nil
        }

        guard let loc = train.locomotive else {
            return nil
        }
        
        let nextBlock: Block

        if train.scheduling == .unmanaged {
            guard let nb = try nextValidBlockForLocomotive(from: currentBlock, train: train) else {
                return nil
            }
            nextBlock = nb
        } else {
            if loc.directionForward {
                guard let nb = train.leading.blocks.first else {
                    return nil
                }
                nextBlock = nb
            } else {
                guard let nb = train.occupied.blocks.dropFirst().first else {
                    return nil
                }
                nextBlock = nb
            }
            
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
        
        // Note: grab the last transition which is the one that leads to the `nextBlock`.
        guard let lastTransition = transitions.last else {
            throw LayoutError.noTransition(fromBlockId: fromBlock.id, toBlockId: nextBlock.id)
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
        if let entryFeedback = self.feedback(for: entryFeedbackId) {
            return .init(block: nextBlock, feedback: entryFeedback, direction: nextBlockDirectionOfTravel)
        } else {
            return nil
        }
    }

}
