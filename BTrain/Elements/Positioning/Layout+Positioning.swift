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
    
    /// Sets a train to a specific block.
    ///
    /// - Parameters:
    ///   - trainId: the train
    ///   - toBlockId: the block in which to put the train
    ///   - position: the position in the block in which to put the train
    ///   - direction: the direction in the block in which to put the train
    //TODO: move routeIndex outside of it and have the caller update it
    func setTrainToBlock(_ trainId: Identifier<Train>, _ toBlockId: Identifier<Block>, position: TrainLocation? = nil, direction: Direction) throws {
        guard let train = trains[trainId] else {
            throw LayoutError.trainNotFound(trainId: trainId)
        }
        
        guard let toBlock = blocks[toBlockId] else {
            throw LayoutError.blockNotFound(blockId: toBlockId)
        }
        
        guard toBlock.trainInstance == nil || toBlock.trainInstance?.trainId == trainId else {
            throw LayoutError.blockNotEmpty(blockId: toBlockId)
        }
        
        guard toBlock.reservation == nil || toBlock.reservation?.trainId == train.id else {
            throw LayoutError.cannotReserveBlock(block: toBlock, train: train, reserved: toBlock.reservation!)
        }
        
        let directionInBlock: Direction
        if let position = position {
            train.position = position
            // When the position is specified, `direction` is the direction of travel inside the block.
            directionInBlock = direction
        } else {
            if direction == .next {
                if train.allowedDirections == .forward {
                    train.position = .both(blockId: toBlockId, index: toBlock.feedbacks.count)
                } else {
                    train.position = .block(blockId: toBlockId, front: toBlock.feedbacks.count, back: 0)
                }
            } else {
                if train.allowedDirections == .forward {
                    train.position = .both(blockId: toBlockId, index: 0)
                } else {
                    train.position = .block(blockId: toBlockId, front: 0, back: toBlock.feedbacks.count)
                }
            }
            
            // When the position is not specified, `direction` is the direction in which the train is
            // positioned within the block, with the locomotive in that direction of travel.
            // This scenario here happens only when the user sets the train on the switchboard. When
            // the train moves from block to block, the position is specified.
            // TODO: can we simplify that by having a different method parameter? Either the (position, directionOfTravel) or directionOfLayoutInBlock is specified.
            if train.directionForward {
                directionInBlock = direction
            } else {
                directionInBlock = direction.opposite
            }
        }
        
        // Reserve the block
        toBlock.reservation = Reservation(trainId: train.id, direction: directionInBlock)
        toBlock.trainInstance = TrainInstance(trainId, directionInBlock)
        
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
    
}
