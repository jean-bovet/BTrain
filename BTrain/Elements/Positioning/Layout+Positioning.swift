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
    
    /// Sets the train into the specified block, at the specified position and direction of travel in the block.
    ///
    /// - Parameters:
    ///   - train: the train
    ///   - toBlockId: the block
    ///   - position: the position
    ///   - directionOfTravelInBlock: the direction of travel
    func setTrainToBlock(_ train: Train, _ toBlockId: Identifier<Block>, position: TrainLocation, directionOfTravelInBlock: Direction) throws {
        guard let toBlock = blocks[toBlockId] else {
            throw LayoutError.blockNotFound(blockId: toBlockId)
        }
        
        guard toBlock.trainInstance == nil || toBlock.trainInstance?.trainId == train.id else {
            throw LayoutError.blockNotEmpty(blockId: toBlockId)
        }
        
        guard toBlock.reservation == nil || toBlock.reservation?.trainId == train.id else {
            throw LayoutError.cannotReserveBlock(block: toBlock, train: train, reserved: toBlock.reservation!)
        }
        
        train.position = position
        
        // Reserve the block
        toBlock.reservation = Reservation(trainId: train.id, direction: directionOfTravelInBlock)
        toBlock.trainInstance = TrainInstance(train.id, directionOfTravelInBlock)
        
        // Assign the block to the train
        train.block = toBlock
    }
    
    /// Returns all the feedbacks that are currently detected in any of the occupied blocks by the train.
    ///
    /// Because a train can have more than one magnet to detect its position (besides under the front locomotive),
    /// we need to take into consideration all the feedback triggers within all the occupied blocks.
    ///
    /// - Returns: array of detected feedback and their position
    func allActiveFeedbackPositions(train: Train) throws -> [FeedbackPosition] {
        var positions = [FeedbackPosition]()
                
        for block in train.occupied.blocks {
            for (feedbackIndex, feedback) in block.feedbacks.enumerated() {
                guard let f = feedbacks[feedback.feedbackId], f.detected else {
                    continue
                }
                
                guard let fd = feedback.distance else {
                    throw LayoutError.feedbackDistanceNotSet(feedback: feedback)
                }
                
                positions.append(FeedbackPosition(blockId: block.id, index: feedbackIndex, distance: fd))
            }
        }
        
        return positions
    }
            
}
