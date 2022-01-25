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
                // TODO: take turnout length into account
                guard turnout.reserved == nil else {
                    throw LayoutError.turnoutAlreadyReserved(turnout: turnout)
                }
                turnout.reserved = train.id
            } else if let block = info.block, let blockLength = block.length, let direction = info.direction {
                // TODO: take block length into consideration if no feedback distance is defined?
                guard block.reserved == nil || info.index == 0 else {
                    throw LayoutError.blockAlreadyReserved(block: block)
                }
                
                if reserveBlockParts(train: train, remainingTrainLength: &remainingTrainLength, block: block, headBlock: info.index == 0, direction: direction) == .stop {
                    return .stop
                }
                block.reserved = .init(trainId: train.id, direction: direction)
            }

            if remainingTrainLength > 0 {
                return .continue
            } else {
                return .stop
            }
        })
    }
    
    private func reserveBlockParts(train: Train, remainingTrainLength: inout Double, block: Block, headBlock: Bool, direction: Direction) -> ElementVisitor.VisitorCallbackResult {
        let trainInstance = Block.TrainInstance(train.id, direction.opposite)
        var parts = [Int:Block.TrainInstance.TrainPart]()

        // [ 0 | 1 | 2 ]
        //   =   =>
        //   <   <   <   (direction previous)
        //      <=   =
        //   >   >   >   (direction next)
        var position = train.position
        parts[position] = headBlock ? .locomotive : .wagon
        guard let partLength = block.partLenght(at: position) else {
            return .stop
        }
        remainingTrainLength -= partLength
        
        let increment = direction == .previous ? -1 : 1

        position += increment
        while ((increment < 0 && position >= 0) || (increment > 0 && position < block.feedbacks.count + 1)) && remainingTrainLength > 0 {
            parts[position] = .wagon
            guard let partLength = block.partLenght(at: position) else {
                return .stop
            }
            remainingTrainLength -= partLength
            
            position += increment
        }
        
        trainInstance.parts = parts
        block.train = trainInstance
        
        return .continue
    }

}
