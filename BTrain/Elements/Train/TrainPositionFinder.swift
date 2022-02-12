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

final class TrainPositionFinder {
        
    // Returns the block that contains the last wagon of the train
    // which is the "lead wagon" when the locomotive pushes the train.
    static func headWagonBlockFor(train: Train, startAtNextPosition: Bool = false, layout: Layout) throws -> Block? {
        guard train.wagonsPushedByLocomotive else {
            fatalError("It is an error to ask for the head wagon when the locomotive is not pushing its wagons")
        }
        
        let visitor = TrainVisitor(layout: layout)
        
        var lastVisitedBlock: Block? = nil
        try visitor.visit(train: train, startAtNextPosition: startAtNextPosition) { transition in
            // Transition is only a virtual element, nothing to do.
        } turnoutCallback: { turnout in
            // Note: we are ignoring any occupied turnout that might
            // exist past the lastVisitedBlock. We might want to take them
            // into consideration for more safety when determining the next
            // block that should be free in front of the train?
        } blockCallback: { block, attributes in
            lastVisitedBlock = block
        }
        
        return lastVisitedBlock
    }
    
    // Returns true if the block in front of the block containing the head wagon is free.
    static func isFreeBlockInFrontOfHeadWagon(train: Train, layout: Layout) throws -> Bool {
        guard let headWagonBlock = try headWagonBlockFor(train: train, startAtNextPosition: false, layout: layout) else {
            throw LayoutError.headWagonNotFound(train: train)
        }
                        
        guard let blockId = train.blockId else {
            throw LayoutError.trainNotAssignedToABlock(trainId: train.id)
        }
        
        guard let block = layout.block(for: blockId) else {
            throw LayoutError.blockNotFound(blockId: blockId)
        }
        
        guard let trainInstance = block.train else {
            throw LayoutError.trainNotFoundInBlock(blockId: blockId)
        }

        guard let nextBlock = try ElementVisitor.blockAfter(block: headWagonBlock, direction: trainInstance.direction, layout: layout) else {
            return false
        }
        
        return nextBlock.reserved == nil
    }

}
