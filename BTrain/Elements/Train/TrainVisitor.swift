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

// This class provides an easy way to visit all the elements (transitions, turnouts and blocks)
// that a train occupies, including the individual parts of each block.
final class TrainVisitor {
    struct BlockAttributes {
        // True if this is the block at the front of the train (in the direction of travel)
        let frontBlock: Bool
        var backBlock: Bool

        // Direction of travel of the train inside the block
        let trainDirection: Direction
    }

    typealias TransitionCallbackBlock = (ITransition) throws -> Void
    typealias TurnoutCallbackBlock = (ElementVisitor.TurnoutInfo) throws -> Void
    typealias BlockCallbackBlock = (Block, BlockAttributes) throws -> Void

    let layout: Layout
    let visitor: ElementVisitor

    init(layout: Layout) {
        self.layout = layout
        visitor = ElementVisitor(layout: layout)
    }

    struct VisitResult {
        var transitions = [ITransition]()
        var turnouts = [ElementVisitor.TurnoutInfo]()
        var blocks = [ElementVisitor.BlockInfo]()
        var remainingTrainLength = 0.0
    }
    
    /// Visit all the elements that a train occupies - transitions, turnouts and blocks - starting
    /// with the front block (the block at the front of the train in its direction of travel) and going backwards.
    ///
    /// - Parameters:
    ///   - train: the train
    ///   - transitionCallback: the callback invoked for each transition visited
    ///   - turnoutCallback: the callback invoked for each turnout visited
    ///   - blockCallback: the callback invoked for each block visited
    /// - Returns: true if all the train fits into the blocks, false otherwise.
    func visit(train: Train,
               transitionCallback: TransitionCallbackBlock,
               turnoutCallback: TurnoutCallbackBlock,
               blockCallback: BlockCallbackBlock) throws -> VisitResult
    {
        guard let frontBlock = train.block else {
            throw LayoutError.trainNotAssignedToABlock(train: train)
        }

        guard let trainInstance = frontBlock.trainInstance else {
            throw LayoutError.trainNotFoundInBlock(blockId: frontBlock.id)
        }

        guard let trainLength = train.length else {
            // If the train length is not defined, we invoke once the callback for the entire block
            try blockCallback(frontBlock, BlockAttributes(frontBlock: true, backBlock: true, trainDirection: trainInstance.direction))
            return VisitResult()
        }

        guard let locomotive = train.locomotive else {
            throw LayoutError.locomotiveNotAssignedToTrain(train: train)
        }
                
        // Keep track of the remaining train length that needs to have reserved blocks
        var remainingTrainLength = trainLength
            
        // Always visit the train in the opposite direction of travel (by definition)
        let directionOfVisit = trainInstance.direction.opposite

        var result = VisitResult()
        try visitor.visit(fromBlockId: frontBlock.id, direction: directionOfVisit, callback: { info in
            if let transition = info.transition {
                // Transition is just a virtual connection between two elements, no physical length exists.
                result.transitions.append(transition)
                try transitionCallback(transition)
            } else if let turnoutInfo = info.turnout {
                result.turnouts.append(turnoutInfo)
                if let length = turnoutInfo.turnout.length {
                    remainingTrainLength -= length
                }
                try turnoutCallback(turnoutInfo)
            } else if let blockInfo = info.block {
                result.blocks.append(blockInfo)
                remainingTrainLength = try visitBlockParts(trainPosition: train.position,
                                                           remainingTrainLength: remainingTrainLength,
                                                           block: blockInfo.block,
                                                           frontBlock: info.index == 0,
                                                           trainForward: locomotive.directionForward,
                                                           directionOfVisit: blockInfo.direction,
                                                           blockCallback: blockCallback)
                
                // Note: if the train length end up in a turnout, its back (or front) position won't be updated and left to be nil
                if remainingTrainLength <= 0 {
                    // Update back position of the train
                    let pos = backPosition(in: blockInfo.block, with: remainingTrainLength, directionOfVisit: directionOfVisit, directionForward: locomotive.directionForward)
                    // Note: when moving backward, `pos` is the position of the trail of the train in
                    // the direction of travel. And because the front and back positions are always the same
                    // regardless of the direction of travel, we need to update either one.
                    if locomotive.directionForward {
                        train.position.back = pos
                    } else {
                        train.position.front = pos
                    }
                }
            }

            if remainingTrainLength > 0 {
                return .continue
            } else {
                return .stop
            }
        })

        result.remainingTrainLength = remainingTrainLength
        return result
    }

    // TODO: static and move to common Positioning files?
    func backPosition(in block: Block, with remainingTrainLength: Double, directionOfVisit: Direction, directionForward: Bool) -> TrainPosition {
        //      [      ]
        // <-------{ d } where d = remainingTrainLength
        // if d == 0, the train occupies all of the last block
        // if d > 0, the train occupies some portion of the last block
        let d = abs(remainingTrainLength)

        let index: Int
        let distance: Double
        let blockLength = block.length ?? 0
        if directionOfVisit == .next {
            if directionForward {
                // <[   ]
                //  {d}------> (train)
                //     <------ (visit)
                distance = blockLength - d
                index = block.feedbacks.indexOfFeedback(withDistance: distance, directionOfVisit: directionOfVisit)
            } else {
                //        [   ]>
                //   ------< (train)
                //   ------> (visit)
                distance = blockLength - d
                index = block.feedbacks.indexOfFeedback(withDistance: distance, directionOfVisit: directionOfVisit)
            }
        } else {
            if directionForward {
                // [   ]>
                // {d}------> (train)
                //    <------ (visit)
                distance = d
                index = block.feedbacks.indexOfFeedback(withDistance: distance, directionOfVisit: directionOfVisit)
            } else {
                //        [   ]<
                //   ------<{d} (train)
                //   ------>    (visit)
                distance = d
                index = block.feedbacks.indexOfFeedback(withDistance: distance, directionOfVisit: directionOfVisit)
            }
        }
        return .init(blockId: block.id, index: index, distance: distance)
    }
    
    /// Visit all the parts of a block. A block part is a portion of a block between two feedbacks or the beginning/end of
    /// the block and a feedback.
    /// - Parameters:
    ///   - trainPosition: the position of the train, valid only if headBlock is true
    ///   - remainingTrainLength: the remaining train length available to visit the block
    ///   - block: the block to visit
    ///   - frontBlock: true if this block is the front block, that is the first block
    ///   - trainForward: true if the train is moving forward, false if moving backward
    ///   - directionOfVisit: the direction in which this block is visited
    ///   - blockCallback: callback invoked for each part that is being visited
    /// - Returns: the remaining train length after visiting this block
    private func visitBlockParts(trainPosition: TrainLocation,
                                 remainingTrainLength: Double,
                                 block: Block,
                                 frontBlock: Bool,
                                 trainForward: Bool,
                                 directionOfVisit: Direction,
                                 blockCallback: BlockCallbackBlock) throws -> Double {
        var bv = BlockAttributes(frontBlock: frontBlock, backBlock: frontBlock, trainDirection: directionOfVisit.opposite)
        let occupiedLength = occupiedLengthOfTrainInBlock(block: block, trainPosition: trainPosition, frontBlock: frontBlock, directionOfVisit: directionOfVisit, trainForward: trainForward)
        let currentRemainingTrainLength = remainingTrainLength - occupiedLength
        
        // The back block is detected when there are no more remaining train length
        bv.backBlock = currentRemainingTrainLength <= 0
        
        try blockCallback(block, bv)
        
        return currentRemainingTrainLength
    }
        
    // TODO: static and move to common Positioning files?
    func occupiedLengthOfTrainInBlock(block: Block, trainPosition: TrainLocation, frontBlock: Bool, directionOfVisit: Direction, trainForward: Bool) -> Double {
        let blockLength = block.length ?? 0 // TODO: throw if block.length is not defined?
        
        // directionOfVisit: always in the opposite direction of travel of the train
        let lengthOfTrainInBlock: Double
        if frontBlock {
            let frontDistance = (trainForward ? trainPosition.front?.distance : trainPosition.back?.distance) ?? 0
            
            
            // TODO: throw
            if trainForward {
                assert(trainPosition.front?.blockId == block.id)
            } else {
                assert(trainPosition.back?.blockId == block.id)
            }
            
            if directionOfVisit == .next {
                if trainForward {
                    // [     >
                    //   <-------|
                    //   f       b
                    lengthOfTrainInBlock = blockLength - frontDistance
                } else {
                    // [     >
                    //   |-------<
                    //   b       f
                    lengthOfTrainInBlock = blockLength - frontDistance
                }
            } else {
                if trainForward {
                    // <     ]
                    //   <-------|
                    //   f       b
                    lengthOfTrainInBlock = frontDistance
                } else {
                    // <     ]
                    //   |-------<
                    //   b       f
                    lengthOfTrainInBlock = frontDistance
                }
            }
        } else {
            // Either the entire block is used by the the train or the block
            // is only partially used by the remaining of the train.
            lengthOfTrainInBlock = blockLength
        }
        
        return abs(lengthOfTrainInBlock)
    }

}

extension Array where Element == Block.BlockFeedback {
    
    /// Returns the index of the feedback that corresponds to the specified distance.
    ///
    ///     Block:    [   f0   f1   f2   ]>
    ///     Distance: |------>
    ///     Index:      0    1    2    3
    ///     Train:           <----------------
    ///     Visit:           ---------------->
    ///     
    /// - Parameters:
    ///   - distance: the distance
    ///   - directionOfVisit: the direction of visit of the block
    /// - Returns: the feedback index
    func indexOfFeedback(withDistance distance: Double, directionOfVisit: Direction) -> Int {
        //TODO: using directionOfVisit?
        for (findex, feedback) in enumerated() {
            if let fd = feedback.distance, distance <= fd {
                return findex
            }
        }
        return count
    }

}
