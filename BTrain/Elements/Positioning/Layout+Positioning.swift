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

// TODO: continue to group all these functions together
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
        train.blockId = toBlock.id
    }
    
    /// Returns all the feedbacks that are currently detected in any of the occupied blocks by the train.
    ///
    /// Because a train can have more than one magnet to detect its position (besides under the front locomotive),
    /// we need to take into consideration all the feedback triggers within all the occupied blocks.
    ///
    /// - Returns: array of detected feedback and their position
    func allActiveFeedbackPositions(train: Train) -> [FeedbackPosition] {
        var positions = [FeedbackPosition]()
                
        for block in train.occupied.blocks {
            for (feedbackIndex, feedback) in block.feedbacks.enumerated() {
                guard let f = feedbacks[feedback.feedbackId], f.detected else {
                    continue
                }
                
                positions.append(FeedbackPosition(blockId: block.id, index: feedbackIndex))
            }
        }
        
        return positions
    }
    
    /// Returns the block at the end of the train (from its direction of travel).
    ///
    /// This function relies on the occupied block to be properly set.
    /// - Parameter train: the train
    /// - Returns: the tail block of the train or nil if not found
    func tailBlock(train: Train) -> Block? {
        if let tailBlock = train.occupied.blocks.last {
            return tailBlock
        } else {
            return blocks[train.blockId]
        }
    }
    
    func trainPosition(train: Train) -> TrainLocation? {
        guard let tailBlock = tailBlock(train: train) else {
            return nil
        }

        guard let tailInstance = tailBlock.trainInstance else {
            return nil
        }
        
        if train.directionForward {
            // This means the train was moving backward before the toggle happened
            if tailInstance.direction == .next {
                if let tailIndex = tailInstance.parts.keys.sorted().first {
                    return .front(blockId: tailBlock.id, index: tailIndex)
                }
            } else {
                if let tailIndex = tailInstance.parts.keys.sorted().last {
                    return .front(blockId: tailBlock.id, index: tailIndex)
                }
            }
        } else {
            // This means the train was moving forward before the toggle happened
            if tailInstance.direction == .next {
                if let tailIndex = tailInstance.parts.keys.sorted().first {
                    return .back(blockId: tailBlock.id, index: tailIndex)
                }
            } else {
                if let tailIndex = tailInstance.parts.keys.sorted().last {
                    return .back(blockId: tailBlock.id, index: tailIndex)
                }
            }
        }
        
        return nil
    }
    
}
