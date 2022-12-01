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
            }

            if remainingTrainLength > 0 {
                return .continue
            } else {
                return .stop
            }
        })

        result.remainingTrainLength = remainingTrainLength
//         Returns true if all the train length has been visited
//        return remainingTrainLength <= 0
        return result
    }

    /// Visit all the parts of a block. A block part is a portion of a block between two feedbacks or the beginning/end of
    /// the block and a feedback.
    /// - Parameters:
    ///   - trainPosition: the position of the train, valid only if headBlock is true
    ///   - remainingTrainLength: the remaining train length available to visit the block
    ///   - block: the block to visit
    ///   - headBlock: true if this block is the head block, where the locomotive is located
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
        let occupiedLength = occupiedLengthOfTrainInBlock(block: block, trainPosition: trainPosition, directionOfVisit: directionOfVisit, trainForward: trainForward)
        let currentRemainingTrainLength = remainingTrainLength - occupiedLength
        
        // The back block is detected when there are no more remaining train length
        bv.backBlock = currentRemainingTrainLength <= 0
        
        try blockCallback(block, bv)
        
        return currentRemainingTrainLength
    }
        
    /// Returns the length of the portion of the block occupied by the train
    /// - Parameters:
    ///   - block: the block
    ///   - trainPosition: the train position
    ///   - directionOfVisit: the direction of visit, which is always in the opposite direction of the travel direction of the train
    ///   - trainForward: true if the train moves forward, false if the train moves backward
    /// - Returns: the length of occupation, in cm
    func occupiedLengthOfTrainInBlock(block: Block, trainPosition: TrainLocation, directionOfVisit: Direction, trainForward: Bool) -> Double {
        let blockLength = block.length ?? 0 // TODO: throw if block.length is not defined?
        let frontDistance = trainPosition.front?.distance ?? 0
        let backDistance = trainPosition.back?.distance ?? 0

        let frontBlock = block.id == trainPosition.front?.blockId
        let backBlock = block.id == trainPosition.back?.blockId
        
        // directionOfVisit: always in the opposite direction of travel of the train
        let lengthOfTrainInBlock: Double
        if frontBlock && backBlock {
            if directionOfVisit == .next {
                if trainForward {
                    // [           >
                    //   <-------|
                    //   f       b
                    lengthOfTrainInBlock = backDistance - frontDistance
                } else {
                    // [            >
                    //   |-------<
                    //   b       f
                    lengthOfTrainInBlock = frontDistance - backDistance
                }
            } else {
                if trainForward {
                    // <           ]
                    //   <-------|
                    //   f       b
                    lengthOfTrainInBlock = frontDistance - backDistance
                } else {
                    //  <          ]
                    //   |-------<
                    //   b       f
                    lengthOfTrainInBlock = backDistance - frontDistance
                }
            }
        } else if frontBlock {
            if directionOfVisit == .next {
                if trainForward {
                    // [     >
                    //   <-------|
                    //   f       b
                    lengthOfTrainInBlock = blockLength - frontDistance
                } else {
                    //         [     >
                    //   |-------<
                    //   b       f
                    lengthOfTrainInBlock = frontDistance
                }
            } else {
                if trainForward {
                    // <     ]
                    //   <-------|
                    //   f       b
                    lengthOfTrainInBlock = frontDistance
                } else {
                    //         <     ]
                    //   |-------<
                    //   b       f
                    lengthOfTrainInBlock = blockLength - frontDistance
                }
            }
        } else if backBlock {
            if directionOfVisit == .next {
                if trainForward {
                    //        [     >
                    //   <-------|
                    //   f       b
                    lengthOfTrainInBlock = backDistance
                } else {
                    // [     >
                    //   |-------<
                    //   b       f
                    lengthOfTrainInBlock = blockLength - backDistance
                }
            } else {
                if trainForward {
                    //        <     ]
                    //   <-------|
                    //   f       b
                    lengthOfTrainInBlock = blockLength - backDistance
                } else {
                    // <     ]
                    //   |-------<
                    //   b       f
                    lengthOfTrainInBlock = backDistance
                }
            }
        } else {
            // Full block is used by train
            lengthOfTrainInBlock = blockLength
        }
        
        return abs(lengthOfTrainInBlock)
    }
}
