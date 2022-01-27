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

// This extension of the TrainController manages the manual operation of the train.
// In other words, this extension manages to follow the train on the layout
// while it is operated by someone on the Digital Controller.
extension TrainController {
    
    func handleManualOperation() throws -> Result {
        var result: Result = .none
        if try handleManualTrainMoveToNextBlock() == .processed {
            result = .processed
        }
        
        if try handleTrainMove() == .processed {
            result = .processed
        }
        // TODO: stop the train if there is no possible next block, only if the train is at the end of the block
        return result
    }
    
    private func handleManualTrainMoveToNextBlock() throws -> Result {
        guard train.speed.kph > 0 else {
            return .none
        }
                
        guard let currentBlock = layout.currentBlock(train: train) else {
            return .none
        }

        guard let nextBlock = layout.nextBlock(from: currentBlock) else {
            return .none
        }
        
        // Find out what is the entry feedback for the next block
        let (entryFeedback, direction) = try layout.entryFeedback(from: currentBlock, to: nextBlock)
        
        guard let entryFeedback = entryFeedback, entryFeedback.detected else {
            // The entry feedback is not yet detected, nothing more to do
            return .none
        }
        
        guard let position = nextBlock.indexOfTrain(forFeedback: entryFeedback.id, direction: direction) else {
            throw LayoutError.feedbackNotFound(feedbackId: entryFeedback.id)
        }
                
        debug("Train \(train) enters block \(nextBlock) at position \(position), direction \(direction)")
                
        // Set the train to its new block. This method will also free up all the other blocks from the train, expect
        // the blocks trailing the train depending on its length and the length of the blocks.
        // Note: we will reserve again the leading blocks below in `reserveNextBlocks`.
        try layout.setTrainToBlock(train.id, nextBlock.id, position: .custom(value: position), direction: direction)
                                                
        return .processed
    }
}
