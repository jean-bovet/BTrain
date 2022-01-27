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
    
    // This method reserves all the necessary blocks (and parts of the block) to fit
    // the specified train with all its length, taking into account the length of each block.
    func reserveBlocksForTrainLength(train: Train) throws {
        guard let fromBlockId = train.blockId else {
            throw LayoutError.trainNotAssignedToABlock(trainId: train.id)
        }
        
        guard let fromBlock = self.block(for: fromBlockId) else {
            throw LayoutError.blockNotFound(blockId: fromBlockId)
        }
        
        guard let trainInstance = fromBlock.train else {
            throw LayoutError.trainNotFoundInBlock(blockId: fromBlockId)
        }
        
        guard let trainLength = train.length else {
            return
        }
        
        let trainDirection = trainInstance.direction
        
        // First, free all the reserved block behind the train so we can reserve them again
        // using the length of the train in consideraion
        try freeReservedElements(fromBlockId: fromBlockId, direction: trainDirection.opposite, trainId: train.id)

        var remainingTrainLength = trainLength

        let visitor = ElementVisitor(layout: self)
        try visitor.visit(fromBlockId: fromBlock.id, direction: trainDirection.opposite, callback: { info in
            if let transition = info.transition {
                // Transition is just a virtual connection between two elements,
                // no physical length exists.
                guard transition.reserved == nil else {
                    throw LayoutError.transitionAlreadyReserved(transition: transition)
                }
                transition.reserved = train.id
            } else if let turnout = info.turnout {
                guard turnout.reserved == nil else {
                    throw LayoutError.turnoutAlreadyReserved(turnout: turnout)
                }
                if let length = turnout.length {
                    remainingTrainLength -= length
                }
                turnout.reserved = train.id
            } else if let block = info.block, let direction = info.direction {
                guard block.reserved == nil || info.index == 0 else {
                    throw LayoutError.blockAlreadyReserved(block: block)
                }
                
                if block.length == nil {
                    // TODO: throw appropriate exception
                    return .stop
                }
                
                remainingTrainLength = reserveBlockParts(train: train, remainingTrainLength: remainingTrainLength, block: block, headBlock: info.index == 0, direction: direction)
                block.reserved = .init(trainId: train.id, direction: direction)
            }

            if remainingTrainLength > 0 {
                return .continue
            } else {
                return .stop
            }
        })
    }
    
    private func reserveBlockParts(train: Train, remainingTrainLength: Double, block: Block, headBlock: Bool, direction: Direction) -> Double {
        let trainInstance = TrainInstance(train.id, direction.opposite)
        trainInstance.parts.removeAll()
        
        var currentRemainingTrainLength = remainingTrainLength
        
        // [ 0 | 1 | 2 ]
        //   =   =>
        //   <   <   <   (direction previous)
        //      <=   =
        //   >   >   >   (direction next)
                
        // Determine the starting position where to begin filling out parts of the block
        var position: Int
        if headBlock {
            position = train.position
        } else {
            position = direction == .previous ? block.feedbacks.count : 0
        }
        
        let increment = direction == .previous ? -1 : 1

        // Gather all the part length to ensure they are all defined.
        if let allPartsLength = block.allPartsLength() {
            if headBlock {
                trainInstance.parts[position] = .locomotive
                // Don't take into consideration the length of that part
                // because the locomotive could be at the beginning of the part.
                // This will get more precise once we manage the distance
                // using the real speed conversion.
            } else {
                trainInstance.parts[position] = .wagon
                currentRemainingTrainLength -= allPartsLength[position]!
            }
            
            position += increment
            while ((increment < 0 && position >= 0) || (increment > 0 && position < block.feedbacks.count + 1)) && currentRemainingTrainLength > 0 {
                trainInstance.parts[position] = .wagon
                currentRemainingTrainLength -= allPartsLength[position]!

                position += increment
            }
        } else if let length = block.length {
            // If the parts length are not available, let's use the block full length
            trainInstance.parts[position] = headBlock ? .locomotive : .wagon

            position += increment
            while ((increment < 0 && position >= 0) || (increment > 0 && position < block.feedbacks.count + 1)) {
                trainInstance.parts[position] = .wagon
                position += increment
            }

            currentRemainingTrainLength -= length
        }
        
        block.train = trainInstance
        
        return currentRemainingTrainLength
    }

}
