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

/// This class spreads the train from its front block (which is the block at the front of the train in its direction of travel) over
/// all the elements (transitions, turnouts and blocks) until all the length of the train has been spread out.
final class TrainSpreader {
    struct BlockAttributes {
        // True if this is the block at the front of the train (in the direction of travel)
        let frontBlock: Bool

        // True if the is the block at the back of the train (in the direction of travel)
        let backBlock: Bool

        // Direction of travel of the train inside the block
        let trainDirection: Direction
    }

    typealias TransitionCallbackBlock = (Transition) throws -> Void
    typealias TurnoutCallbackBlock = (ElementVisitor.TurnoutInfo) throws -> Void
    typealias BlockCallbackBlock = (Block, BlockAttributes) throws -> Void

    let layout: Layout
    let visitor: ElementVisitor

    init(layout: Layout) {
        self.layout = layout
        visitor = ElementVisitor(layout: layout)
    }

    /// Visit all the elements that a train occupies - transitions, turnouts and blocks - starting
    /// with the front block (the block at the front of the train in its direction of travel) and going backwards.
    /// Updates the parts of the train in each block as well as the "tail" position of the train.
    ///
    /// - Parameters:
    ///   - train: the train
    ///   - transitionCallback: the callback invoked for each transition visited
    ///   - turnoutCallback: the callback invoked for each turnout visited
    ///   - blockCallback: the callback invoked for each block visited
    /// - Returns: the remaining train length, in cm.
    func spread(train: Train,
                transitionCallback: TransitionCallbackBlock,
                turnoutCallback: TurnoutCallbackBlock,
                blockCallback: BlockCallbackBlock) throws -> Double
    {
        // Retrieve the block that is located at the "front" of the train in the direction of travel of the train
        guard let frontBlock = train.block else {
            throw LayoutError.trainNotAssignedToABlock(train: train)
        }

        guard let trainInstance = frontBlock.trainInstance else {
            throw LayoutError.trainNotFoundInBlock(blockId: frontBlock.id)
        }

        guard let trainLength = train.length else {
            // If the train length is not defined, we invoke once the callback for the entire block
            try blockCallback(frontBlock, BlockAttributes(frontBlock: true, backBlock: true, trainDirection: trainInstance.direction))
            return 0
        }

        guard let locomotive = train.locomotive else {
            throw LayoutError.locomotiveNotAssignedToTrain(train: train)
        }

        // Keep track of the remaining train length as we visit the various elements.
        // This method returns when no more train length remains to be visited.
        var remainingTrainLength = trainLength

        // Always visit the train in the opposite direction of travel (by definition).
        let directionOfVisit = trainInstance.direction.opposite

        let position: TrainPosition
        if locomotive.directionForward {
            guard let head = train.positions.head else {
                throw LayoutError.frontPositionNotSpecified(position: train.positions)
            }
            position = head
        } else {
            guard let tail = train.positions.tail else {
                throw LayoutError.backPositionNotSpecified(position: train.positions)
            }
            position = tail
        }

        try visitor.visit(fromBlockId: frontBlock.id, direction: directionOfVisit, callback: { info in
            switch info {
            case .transition(index: _, transition: let transition):
                // Transition is just a virtual connection between two elements, no physical length exists.
                try transitionCallback(transition)
                
            case .turnout(index: _, info: let info):
                if let length = info.turnout.length {
                    remainingTrainLength -= length
                }
                try turnoutCallback(info)
                
            case .block(index: let index, info: let info):
                try visitBlock(blockInfo: info, index: index, train: train, directionForward: locomotive.directionForward, position: position, remainingTrainLength: &remainingTrainLength, blockCallback: blockCallback)
            }

            if remainingTrainLength > 0 {
                return .continue
            } else {
                return .stop
            }
        })

        return remainingTrainLength
    }

    struct SpreadBlockPartInfo {
        let partIndex: Int
        let distance: Double
        let firstPart: Bool
        let lastPart: Bool
        
        static func info(firstPart: Bool, partIndex: Int, remainingTrainLength: Double, feedbackDistance: Double, direction: Direction) -> SpreadBlockPartInfo {
            let distance: Double
            if remainingTrainLength >= 0 {
                distance = feedbackDistance
            } else {
                if direction == .next {
                    distance = feedbackDistance - abs(remainingTrainLength)
                } else {
                    distance = feedbackDistance + abs(remainingTrainLength)
                }
            }
            return .init(partIndex: partIndex, distance: distance, firstPart: firstPart, lastPart: remainingTrainLength <= 0)
        }

    }
    
    struct SpreadBlockInfo {
        let block: ElementVisitor.BlockInfo
        let parts: [SpreadBlockPartInfo]
    }
        
    typealias BlockPartCallbackBlock = (SpreadBlockInfo) throws -> Void

    func spread(blockId: Identifier<Block>, distance: Double, direction: Direction, lengthOfTrain: Double,
                transitionCallback: TransitionCallbackBlock,
                turnoutCallback: TurnoutCallbackBlock,
                blockCallback: BlockPartCallbackBlock) throws -> Bool {
        var remainingTrainLength = lengthOfTrain
        try visitor.visit(fromBlockId: blockId, direction: direction, callback: { info in
            switch info {
            case .transition(index: _, transition: let transition):
                // Transition is just a virtual connection between two elements, no physical length exists.
                try transitionCallback(transition)
                
            case .turnout(index: _, info: let info):
                if let length = info.turnout.length {
                    remainingTrainLength -= length
                }
                try turnoutCallback(info)
                
            case .block(index: let index, info: let info):
                guard let blockLength = info.block.length else {
                    throw LayoutError.blockLengthNotDefined(block: info.block)
                }
                if info.direction == .next {
                    var cursor: Double
                    if index == 0 {
                        cursor = distance
                    } else {
                        cursor = 0
                    }
                    
                    var parts = [SpreadBlockPartInfo]()

                    let feedbacks = info.block.feedbacks
                    for (findex, fb) in feedbacks.enumerated() {
                        guard let fbDistance = fb.distance else {
                            throw LayoutError.feedbackDistanceNotSet(feedback: fb)
                        }
                        if cursor < fbDistance, remainingTrainLength > 0 {
                            let u = fbDistance - cursor
                            assert(u >= 0)
                            remainingTrainLength -= u
                            cursor = fbDistance
                            parts.append(SpreadBlockPartInfo.info(firstPart: index == 0 && parts.isEmpty, partIndex: findex, remainingTrainLength: remainingTrainLength, feedbackDistance: fbDistance, direction: .next))
                        }
                    }

                    if cursor <= blockLength, remainingTrainLength > 0 {
                        let u = blockLength - cursor
                        assert(u >= 0)
                        remainingTrainLength -= u
                        parts.append(SpreadBlockPartInfo.info(firstPart: index == 0 && parts.isEmpty, partIndex: feedbacks.count, remainingTrainLength: remainingTrainLength, feedbackDistance: blockLength, direction: .next))
                    }
                    
                    try blockCallback(.init(block: info, parts: parts))
                } else {
                    var cursor: Double
                    if index == 0 {
                        cursor = distance
                    } else {
                        cursor = blockLength
                    }
                    
                    var parts = [SpreadBlockPartInfo]()

                    let feedbacks = info.block.feedbacks
                    for (findex, fb) in feedbacks.enumerated().reversed() {
                        guard let fbDistance = fb.distance else {
                            throw LayoutError.feedbackDistanceNotSet(feedback: fb)
                        }
                        if cursor > fbDistance, remainingTrainLength > 0 {
                            let u = cursor - fbDistance
                            assert(u >= 0)
                            remainingTrainLength -= u
                            cursor = fbDistance
                            parts.append(SpreadBlockPartInfo.info(firstPart: index == 0 && parts.isEmpty, partIndex: findex+1, remainingTrainLength: remainingTrainLength, feedbackDistance: fbDistance, direction: .previous))
                        }
                    }

                    if cursor >= 0, remainingTrainLength > 0 {
                        let u = cursor - 0
                        assert(u >= 0)
                        remainingTrainLength -= u
                        parts.append(SpreadBlockPartInfo.info(firstPart: index == 0 && parts.isEmpty, partIndex: 0, remainingTrainLength: remainingTrainLength, feedbackDistance: 0, direction: .previous))
                    }
                    
                    try blockCallback(.init(block: info, parts: parts))
                }
            }

            if remainingTrainLength > 0 {
                return .continue
            } else {
                return .stop
            }
        })
        return remainingTrainLength <= 0
    }
    
    private func visitBlock(blockInfo: ElementVisitor.BlockInfo, index: Int, train: Train, directionForward: Bool, position: TrainPosition, remainingTrainLength: inout Double, blockCallback: BlockCallbackBlock) throws {
        // true if this block is the first one to be visited which, by definition, is the block at the "front"
        // of the train in the direction of travel of the train.
        let frontBlock = index == 0

        // The direction of visit for each block can change, depending on the block orientation. Always
        // rely on the direction parameter from the block information.
        let directionOfSpread = blockInfo.direction

        // Compute the length that the train occupies in the block
        let occupiedLength = try occupiedLengthOfTrainInBlock(block: blockInfo.block,
                                                              position: position,
                                                              frontBlock: frontBlock,
                                                              directionOfSpread: directionOfSpread,
                                                              trainForward: directionForward)

        // Subtract it from the remaining train length
        remainingTrainLength -= occupiedLength

        // Create the block attributes.
        // Note: the back block is detected when there are no more remaining train length
        let bv = BlockAttributes(frontBlock: frontBlock, backBlock: remainingTrainLength <= 0, trainDirection: directionOfSpread.opposite)

        // Invoke callback
        try blockCallback(blockInfo.block, bv)

        // If there are no more train length to parse, it means we have reached the "tail" of the train.
        if remainingTrainLength <= 0 {
            // Compute the position of the back of the train, in the direction of travel of the train.
            // Note: the remaining train length represents the space left in the block.
            let pos = try backPositionIn(block: blockInfo.block,
                                         spaceLeftInBlock: abs(remainingTrainLength),
                                         directionOfSpread: directionOfSpread,
                                         directionForward: directionForward)

            if directionForward {
                // Moving forward, the back position is the tail
                train.positions.tail = pos
            } else {
                // Moving backward, the back position is the head
                train.positions.head = pos
            }
        }

        // Update the parts of the train
        fillParts(train: train, trainForward: directionForward, directionOfSpread: directionOfSpread, block: blockInfo.block, bv: bv)
    }

    /// Fill out the parts of the train in the given block
    /// - Parameters:
    ///   - train: the train
    ///   - trainForward: true if the train moves forward, false otherwise
    ///   - directionOfSpread: the direction of visit in the block
    ///   - block: the block
    ///   - bv: the block attributes
    private func fillParts(train: Train, trainForward: Bool, directionOfSpread: Direction, block: Block, bv: BlockAttributes) {
        if bv.frontBlock, bv.backBlock {
            if directionOfSpread == .next {
                if trainForward {
                    // Block: [ 0 1 2 3 ]>
                    // Visit:  ------->
                    // Train:  <-------
                    //         h      t
                    let headIndex = train.positions.head?.index ?? 0
                    let tailIndex = train.positions.tail?.index ?? block.feedbacks.count
                    fill(block: block, fromIndex: headIndex, toIndex: tailIndex, locomotiveIndex: headIndex)
                } else {
                    // Block: [ 0 1 2 3 ]>
                    // Visit:  ------->
                    // Train:  -------<
                    //         t      h
                    let tailIndex = train.positions.tail?.index ?? 0
                    let headIndex = train.positions.head?.index ?? block.feedbacks.count
                    fill(block: block, fromIndex: tailIndex, toIndex: headIndex, locomotiveIndex: headIndex)
                }
            } else {
                if trainForward {
                    // Block: [ 0 1 2 3 ]>
                    // Visit:  <-------
                    // Train:  ------->
                    //         t      h
                    let tailIndex = train.positions.tail?.index ?? 0
                    let headIndex = train.positions.head?.index ?? block.feedbacks.count
                    fill(block: block, fromIndex: tailIndex, toIndex: headIndex, locomotiveIndex: headIndex)
                } else {
                    // Block: [ 0 1 2 3 ]>
                    // Visit:  <-------
                    // Train:  >-------
                    //         h      t
                    let headIndex = train.positions.head?.index ?? 0
                    let tailIndex = train.positions.tail?.index ?? block.feedbacks.count
                    fill(block: block, fromIndex: headIndex, toIndex: tailIndex, locomotiveIndex: headIndex)
                }
            }
        } else if bv.frontBlock {
            // Note: front block as in the block in the front of the train in its direction of travel
            if directionOfSpread == .next {
                if trainForward {
                    // Block: [ 0 1 2 3 ]>
                    // Visit:       ------->
                    // Train:       <-------
                    //              h      t
                    let headIndex = train.positions.head?.index ?? 0
                    let tailIndex = block.feedbacks.count
                    fill(block: block, fromIndex: headIndex, toIndex: tailIndex, locomotiveIndex: headIndex)
                } else {
                    // Block:  [ 0 1 2 3 ]>
                    // Visit:        ------->
                    // Train:        -------<
                    //               t      h
                    let tailIndex = train.positions.tail?.index ?? 0
                    let headIndex = block.feedbacks.count
                    fill(block: block, fromIndex: tailIndex, toIndex: headIndex, locomotiveIndex: headIndex)
                }
            } else {
                if trainForward {
                    // Block:     [ 0 1 2 3 ]>
                    // Visit:  <-------
                    // Train:  ------->
                    //         t      h
                    let tailIndex = 0
                    let headIndex = train.positions.head?.index ?? block.feedbacks.count
                    fill(block: block, fromIndex: tailIndex, toIndex: headIndex, locomotiveIndex: headIndex)
                } else {
                    // Block:     [ 0 1 2 3 ]>
                    // Visit: <-------
                    // Train: >-------
                    //        h      t
                    let headIndex = 0
                    let tailIndex = train.positions.tail?.index ?? block.feedbacks.count
                    fill(block: block, fromIndex: headIndex, toIndex: tailIndex)
                }
            }
        } else if bv.backBlock {
            // back block as in the last block of the train in the direction of travel
            if directionOfSpread == .next {
                if trainForward {
                    // Block:     [ 0 1 2 3 ]>
                    // Visit:  ------->
                    // Train:  <-------
                    //         h      t
                    let headIndex = 0
                    let tailIndex = train.positions.tail?.index ?? block.feedbacks.count
                    fill(block: block, fromIndex: headIndex, toIndex: tailIndex)
                } else {
                    // Block:  [ 0 1 2 3 ]>
                    // Visit:        ------->
                    // Train:        -------<
                    //               t      h
                    let tailIndex = train.positions.tail?.index ?? 0
                    let headIndex = block.feedbacks.count
                    fill(block: block, fromIndex: tailIndex, toIndex: headIndex)
                }
            } else {
                if trainForward {
                    // Block: [ 0 1 2 3 ]>
                    // Visit:      <-------
                    // Train:      ------->
                    //             t      h
                    let tailIndex = train.positions.tail?.index ?? 0
                    let headIndex = block.feedbacks.count
                    fill(block: block, fromIndex: tailIndex, toIndex: headIndex)
                } else {
                    // Block:  [ 0 1 2 3 ]>
                    // Visit:       <-------
                    // Train:       >-------
                    //              h      t
                    let headIndex = train.positions.head?.index ?? 0
                    let tailIndex = block.feedbacks.count
                    fill(block: block, fromIndex: headIndex, toIndex: tailIndex, locomotiveIndex: headIndex)
                }
            }
        } else {
            // Neither front nor back block, this means the entire block is occupied by the train
            fill(block: block, fromIndex: 0, toIndex: block.feedbacks.count)
        }
    }

    /// Fill the part of the block between the specified indexes
    /// - Parameters:
    ///   - block: the block
    ///   - fromIndex: the start index
    ///   - toIndex: the end index
    ///   - locomotiveIndex: if specified, the index in which the locomotive is located
    private func fill(block: Block, fromIndex: Int, toIndex: Int, locomotiveIndex: Int? = nil) {
        if fromIndex <= toIndex {
            for index in fromIndex ... toIndex {
                block.trainInstance?.parts[index] = .wagon
            }
        }
        if let locomotiveIndex = locomotiveIndex {
            block.trainInstance?.parts[locomotiveIndex] = .locomotive
        }
    }

    /// Returns the position of the "tail" of the train in the given block, given the amount of space left in the block
    /// - Parameters:
    ///   - block: the block
    ///   - spaceLeftInBlock: the space left in the block
    ///   - directionOfSpread: the direction of visit in the block
    ///   - directionForward: true if the train is moving forwards, false otherwise
    /// - Returns: the train position
    private func backPositionIn(block: Block, spaceLeftInBlock: Double, directionOfSpread: Direction, directionForward: Bool) throws -> TrainPosition {
        guard let blockLength = block.length else {
            throw LayoutError.blockLengthNotDefined(block: block)
        }

        //      [      ]
        // <-------{ d } where d = remainingTrainLength
        // if d == 0, the train occupies all of the last block
        // if d > 0, the train occupies some portion of the last block
        let d = abs(spaceLeftInBlock)

        let distance: Double
        if directionOfSpread == .next {
            if directionForward {
                // <[   ]
                //  {d}------> (train)
                //     <------ (visit)
                distance = blockLength - d
            } else {
                //        [   ]>
                //   ------< (train)
                //   ------> (visit)
                distance = blockLength - d
            }
        } else {
            if directionForward {
                // [   ]>
                // {d}------> (train)
                //    <------ (visit)
                distance = d
            } else {
                //        [   ]<
                //   ------<{d} (train)
                //   ------>    (visit)
                distance = d
            }
        }
        let index = block.feedbacks.indexOfFeedback(withDistance: distance)
        return .init(blockId: block.id, index: index, distance: distance)
    }

    /// Computes and returns the length that the train occupies in the block.
    ///
    /// - Parameters:
    ///   - block: the block
    ///   - position: the position of the train
    ///   - frontBlock: true if the block is the front block
    ///   - directionOfSpread: the direction of the spread in the block
    ///   - trainForward: true if the train moves forward, false if it moves backward
    /// - Returns: the occupied length of the train in the block
    func occupiedLengthOfTrainInBlock(block: Block, position: TrainPosition, frontBlock: Bool, directionOfSpread: Direction, trainForward: Bool) throws -> Double {
        guard let blockLength = block.length else {
            throw LayoutError.blockLengthNotDefined(block: block)
        }

        let lengthOfTrainInBlock: Double
        if frontBlock {
            let frontDistance = position.distance
            if directionOfSpread == .next {
                if trainForward {
                    // [     >
                    //   <-------|
                    //   h       t
                    lengthOfTrainInBlock = blockLength - frontDistance
                } else {
                    // [     >
                    //   |-------<
                    //   t       h
                    lengthOfTrainInBlock = blockLength - frontDistance
                }
            } else {
                if trainForward {
                    // <     ]
                    //   <-------|
                    //   h       t
                    lengthOfTrainInBlock = frontDistance
                } else {
                    // <     ]
                    //   |-------<
                    //   t       h
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
    /// - Returns: the feedback index
    func indexOfFeedback(withDistance distance: Double) -> Int {
        for (findex, feedback) in enumerated() {
            if let fd = feedback.distance, distance <= fd {
                return findex
            }
        }
        return count
    }
}
