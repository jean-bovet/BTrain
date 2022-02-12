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
        // True if this block is the one containing the locomotive
        // (the head block of the train).
        let headBlock: Bool
                
        // Direction of travel of the train  inside the block
        var trainDirection: Direction
        
        // An array of all the positions that are occupied by the train.
        // Each position starts at 0 up to the number of feedback + 1 and
        // is always in the natural direction of the block.
        // Note: if headBlock is true, the first element in this array is
        // going to be the position of the locomotive
        var positions = [Int]()
    }
    
    typealias TransitionCallbackBlock = (ITransition) throws -> Void
    typealias TurnoutCallbackBlock = (Turnout) throws -> Void
    typealias BlockCallbackBlock = (Block, BlockAttributes) throws -> Void

    let layout: Layout
    let visitor: ElementVisitor
    
    init(layout: Layout) {
        self.layout = layout
        self.visitor = ElementVisitor(layout: layout)
    }
    
    func visit(train: Train,
               startAtNextPosition: Bool = false,
               transitionCallback: TransitionCallbackBlock,
               turnoutCallback: TurnoutCallbackBlock,
               blockCallback: BlockCallbackBlock) throws {
        guard let locomotiveBlockId = train.blockId else {
            throw LayoutError.trainNotAssignedToABlock(trainId: train.id)
        }
        
        guard var locomotiveBlock = layout.block(for: locomotiveBlockId) else {
            throw LayoutError.blockNotFound(blockId: locomotiveBlockId)
        }
                
        guard let trainInstance = locomotiveBlock.train else {
            throw LayoutError.trainNotFoundInBlock(blockId: locomotiveBlockId)
        }
        
        guard let trainLength = train.length else {
            // If the train length is not defined, we invoke once the callback for the entire block
            try blockCallback(locomotiveBlock, BlockAttributes(headBlock: true, trainDirection: trainInstance.direction))
            return
        }
        
        var trainPosition = train.position
        
        // Direction in which the wagon are layout from the locomotive
        var wagonDirection = try locomotiveBlock.wagonDirection(for: train)
        
        if startAtNextPosition {
            // Determine the next position of the locomotive
            trainPosition += 1
            if trainPosition > locomotiveBlock.feedbacks.count {
                if let nextBlock = try ElementVisitor.blockAfter(block: locomotiveBlock, direction: trainInstance.direction, layout: layout) {
                    let (_, direction) = try layout.entryFeedback(from: locomotiveBlock, to: nextBlock)
                    if trainInstance.direction == direction {
                        // No change in direction relative to the new block
                        trainPosition = 0
                    } else {
                        // The train will enter the next block in the previous direction relative to the block
                        trainPosition = nextBlock.feedbacks.count
                        wagonDirection = wagonDirection.opposite
                    }
                    locomotiveBlock = nextBlock
                } else {
                    return
                }
            }
        }

        try visit(trainLength: trainLength, trainPosition: trainPosition, wagonDirection: wagonDirection, wagonsPushedByLocomotive: train.wagonsPushedByLocomotive, trainBlock: locomotiveBlock,
                  transitionCallback: transitionCallback, turnoutCallback: turnoutCallback, blockCallback: blockCallback)
    }
    
    func visit(trainLength: Double,
               trainPosition: Int,
               wagonDirection: Direction,
               wagonsPushedByLocomotive: Bool,
               trainBlock: Block,
               transitionCallback: TransitionCallbackBlock,
               turnoutCallback: TurnoutCallbackBlock,
               blockCallback: BlockCallbackBlock) throws {
        // Keep track of the remaining train length that needs to have reserved blocks
        var remainingTrainLength = trainLength

        try visitor.visit(fromBlockId: trainBlock.id, direction: wagonDirection, callback: { info in
            if let transition = info.transition {
                // Transition is just a virtual connection between two elements, no physical length exists.
                try transitionCallback(transition)
            } else if let turnout = info.turnout {
                if let length = turnout.length {
                    remainingTrainLength -= length
                }
                try turnoutCallback(turnout)
            } else if let block = info.block, let wagonDirection = info.direction {
                // Determine the direction of the train within the current block by using
                // the flag indicating if the wagons are pushed or not by the locomotive.
                let trainDirection = wagonsPushedByLocomotive ? wagonDirection : wagonDirection.opposite
                remainingTrainLength = try visitBlockParts(trainPosition: trainPosition,
                                                           remainingTrainLength: remainingTrainLength,
                                                           block: block,
                                                           headBlock: info.index == 0,
                                                           wagonDirection: wagonDirection,
                                                           trainDirection: trainDirection,
                                                           blockCallback: blockCallback)
            }

            if remainingTrainLength > 0 {
                return .continue
            } else {
                return .stop
            }
        })
    }
    
    private func visitBlockParts(trainPosition: Int, remainingTrainLength: Double, block: Block, headBlock: Bool, wagonDirection: Direction, trainDirection: Direction, blockCallback: BlockCallbackBlock) throws -> Double {
        var currentRemainingTrainLength = remainingTrainLength
        
        // [ 0 | 1 | 2 ]
        //   =   =>
        //   <   <   <   (direction previous)
        //      <=   =
        //   >   >   >   (direction next)
                
        // Determine the starting position where to begin filling out parts of the block
        var position: Int
        if headBlock {
            position = trainPosition
        } else {
            position = wagonDirection == .previous ? block.feedbacks.count : 0
        }
        
        let increment = wagonDirection == .previous ? -1 : 1

        var bv = BlockAttributes(headBlock: headBlock, trainDirection: trainDirection)
        bv.positions.append(position)

        // Gather all the part length to ensure they are all defined.
        if let allPartsLength = try block.allPartsLength() {
            if headBlock {
                // Don't take into consideration the length of that part
                // because the locomotive could be at the beginning of the part.
                // This will get more precise once we manage the distance
                // using the real speed conversion.
            } else {
                currentRemainingTrainLength -= allPartsLength[position]!
            }
            
            position += increment
            while ((increment < 0 && position >= 0) || (increment > 0 && position < block.feedbacks.count + 1)) && currentRemainingTrainLength > 0 {
                bv.positions.append(position)
                currentRemainingTrainLength -= allPartsLength[position]!
                position += increment
            }
        } else if let length = block.length {
            // If the parts length are not available, let's use the block full length
            position += increment
            while ((increment < 0 && position >= 0) || (increment > 0 && position < block.feedbacks.count + 1)) {
                bv.positions.append(position)
                position += increment
            }

            currentRemainingTrainLength -= length
        }
                
        try blockCallback(block, bv)

        return currentRemainingTrainLength
    }
}
