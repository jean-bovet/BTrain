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
                
        // Direction of travel of the train inside the block
        var trainDirection: Direction
        
        // An array of all the positions that are occupied by the train.
        // Each position starts at 0 up to the number of feedback + 1 and
        // is always in the natural direction of the block.
        // Note: if headBlock is true, the first element in this array is
        // going to be the position of the locomotive
        var positions = [Int]()
    }
    
    typealias TransitionCallbackBlock = (ITransition) throws -> Void
    typealias TurnoutCallbackBlock = (ElementVisitor.TurnoutInfo) throws -> Void
    typealias BlockCallbackBlock = (Block, BlockAttributes) throws -> Void

    let layout: Layout
    let visitor: ElementVisitor
    
    init(layout: Layout) {
        self.layout = layout
        self.visitor = ElementVisitor(layout: layout)
    }
    
    /// Visit all the elements that a train occupies - transitions, turnouts and blocks.
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
               blockCallback: BlockCallbackBlock) throws -> Bool {
        guard let locomotiveBlockId = train.blockId else {
            throw LayoutError.trainNotAssignedToABlock(train: train)
        }
        
        guard let locomotiveBlock = layout.block(for: locomotiveBlockId) else {
            throw LayoutError.blockNotFound(blockId: locomotiveBlockId)
        }
                
        guard let trainInstance = locomotiveBlock.train else {
            throw LayoutError.trainNotFoundInBlock(blockId: locomotiveBlockId)
        }
        
        guard let trainLength = train.length else {
            // If the train length is not defined, we invoke once the callback for the entire block
            try blockCallback(locomotiveBlock, BlockAttributes(headBlock: true, trainDirection: trainInstance.direction))
            return true
        }
                        
        // Keep track of the remaining train length that needs to have reserved blocks
        var remainingTrainLength = trainLength

        // Note: the direction in which we visit the blocks is always in the opposite direction
        // of the train. This will change when we support moving backwards with the train
        let direction = trainInstance.direction.opposite
        
        try visitor.visit(fromBlockId: locomotiveBlock.id, direction: direction, callback: { info in
            if let transition = info.transition {
                // Transition is just a virtual connection between two elements, no physical length exists.
                try transitionCallback(transition)
            } else if let turnoutInfo = info.turnout {
                if let length = turnoutInfo.turnout.length {
                    remainingTrainLength -= length
                }
                try turnoutCallback(turnoutInfo)
            } else if let blockInfo = info.block {
                remainingTrainLength = try visitBlockParts(trainPosition: train.position,
                                                           remainingTrainLength: remainingTrainLength,
                                                           block: blockInfo.block,
                                                           headBlock: info.index == 0,
                                                           direction: blockInfo.direction,
                                                           blockCallback: blockCallback)
            }

            if remainingTrainLength > 0 {
                return .continue
            } else {
                return .stop
            }
        })
        
        // Returns true if all the train length has been visited
        return remainingTrainLength <= 0
    }
    
    /// Visit all the parts of a block. A block part is a portion of a block between two feedbacks or the beginning/end of
    /// the block and a feedback.
    /// - Parameters:
    ///   - trainPosition: the position of the train, valid only if headBlock is true
    ///   - remainingTrainLength: the remaining train length available to visit the block
    ///   - block: the block to visit
    ///   - headBlock: true if this block is the head block, where the locomotive is located
    ///   - direction: the direction in which this block is visited
    ///   - blockCallback: callback invoked for each part that is being visited
    /// - Returns: the remaining train length after visiting this block
    private func visitBlockParts(trainPosition: Int, remainingTrainLength: Double, block: Block, headBlock: Bool, direction: Direction, blockCallback: BlockCallbackBlock) throws -> Double {
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
            position = direction == .previous ? block.feedbacks.count : 0
        }
        
        let increment = direction == .previous ? -1 : 1

        // Note: the train direction is always the opposite of the direction of visit
        var bv = BlockAttributes(headBlock: headBlock, trainDirection: direction.opposite)
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
