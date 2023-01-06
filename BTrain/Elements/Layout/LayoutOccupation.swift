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

/// This class handles the spread of a train by:
/// - Starting the spread of the train from the head (or tail) position
/// - Ensuring all the elements in the layout that the train occupies are reserved
/// - Updating the tail (or head) position of the train after the spread is completed
struct LayoutOccupation {
    /// The layout
    let layout: Layout

    /// The train
    let train: Train

    /// The block in which to start the occupation of the train
    let blockId: Identifier<Block>

    /// The distance in the block from which to start the occupation of the train
    let distance: Double

    /// The length of the train to spread and occupy
    let lengthOfTrain: Double

    /// True to mark the last part as the locomotive (in the direction of the spread)
    let markLastPartAsLocomotive: Bool

    /// True to mark the first part as the locomotive (in the direction of the spread)
    let markFirstPartAsLocomotive: Bool

    /// The direction in which to spread the train
    let directionOfSpread: Direction

    /// True if the direction in which the train moves is the same
    /// as the spread direction.
    let directionOfTrainSameAsSpread: Bool

    enum UpdatePosition {
        case tail
        case head
    }

    /// Specify which position, tail or head, of the train must be updated when the last part of the spread is reached
    let lastPartUpdatePosition: UpdatePosition

    /// Occupy the blocks with the entire length of the train
    ///
    /// - Parameters:
    ///   - train: the train
    ///   - layout: the layout
    static func occupyBlocksWith(train: Train, layout: Layout) throws {
        let helper = try LayoutOccupation(train: train, layout: layout)
        try helper.occupyBlocks()
    }

    private init(train: Train, layout: Layout) throws {
        guard let trainLength = train.length else {
            throw LayoutError.trainLengthNotDefined(train: train)
        }

        self.layout = layout
        self.train = train

        if train.directionForward {
            if let head = train.positions.head {
                // When moving forward, the head position is used
                blockId = head.blockId
                distance = head.distance
                lengthOfTrain = trainLength
                markFirstPartAsLocomotive = true
                markLastPartAsLocomotive = false
                lastPartUpdatePosition = .tail
                directionOfSpread = head.direction.opposite
                directionOfTrainSameAsSpread = false
            } else {
                throw LayoutError.headPositionNotSpecified(position: train.positions)
            }
        } else {
            if let tail = train.positions.tail {
                // When moving backwards, prefer to use the tail position if available
                blockId = tail.blockId
                distance = tail.distance
                if tail.direction == .next {
                    // [ >------- ]>
                    //   h      t
                    //   <------- (visit direction)
                    lengthOfTrain = trainLength
                    markFirstPartAsLocomotive = false
                    markLastPartAsLocomotive = true
                    lastPartUpdatePosition = .head
                    directionOfSpread = tail.direction.opposite
                    directionOfTrainSameAsSpread = false
                } else {
                    // [ -------< ]>
                    //   t      h
                    lengthOfTrain = trainLength
                    markFirstPartAsLocomotive = false
                    markLastPartAsLocomotive = true
                    lastPartUpdatePosition = .head
                    directionOfSpread = tail.direction.opposite
                    directionOfTrainSameAsSpread = false
                }
            } else if let head = train.positions.head {
                // If the tail position is not available, the front position is used
                blockId = head.blockId
                distance = head.distance
                if head.direction == .next {
                    // [ >------- ]>
                    //   h      t
                    lengthOfTrain = trainLength
                    markFirstPartAsLocomotive = true
                    markLastPartAsLocomotive = false
                    lastPartUpdatePosition = .tail
                    directionOfSpread = head.direction
                    directionOfTrainSameAsSpread = true
                } else {
                    // [ -------< ]>
                    //   t      h
                    lengthOfTrain = trainLength
                    markFirstPartAsLocomotive = true
                    markLastPartAsLocomotive = false
                    lastPartUpdatePosition = .tail
                    directionOfSpread = head.direction
                    directionOfTrainSameAsSpread = true
                }
            } else {
                throw LayoutError.noPositionsSpecified(position: train.positions)
            }
        }
    }

    private func occupyBlocks() throws {
        let occupation = train.occupied
        occupation.clear()

        // Note: the occupied elements are always ordered in the direction of travel of the train.
        // - If the direction of the train is the same as the spread, it means the elements will be discovered and added in order.
        // - If the direction of the train is the opposite as the spread, it means the elements will be discovered
        //   in reverse order, so we need to insert them at the beginning of the occupied list to ensure proper ordering.
        let insertAtBeginning = !directionOfTrainSameAsSpread
        
        let spreader = TrainSpreader(layout: layout)
        let success = try spreader.spread(blockId: blockId, distance: distance, direction: directionOfSpread, lengthOfTrain: lengthOfTrain, transitionCallback: { transition in
            guard transition.reserved == nil else {
                throw LayoutError.transitionAlreadyReserved(train: train, transition: transition)
            }
            transition.reserved = train.id
            transition.train = train.id
            occupation.append(transition, atBeginning: insertAtBeginning)
        }, turnoutCallback: { turnoutInfo in
            let turnout = turnoutInfo.turnout

            guard turnout.reserved == nil else {
                throw LayoutError.turnoutAlreadyReserved(turnout: turnout)
            }
            turnout.reserved = Turnout.Reservation(train: train.id, sockets: turnoutInfo.sockets)
            turnout.train = train.id
            occupation.append(turnout, atBeginning: insertAtBeginning)
        }, blockCallback: { spreadBlockInfo in
            let blockInfo = spreadBlockInfo.blockInfo
            let block = blockInfo.block
            guard block.reservation == nil else {
                throw LayoutError.blockAlreadyReserved(block: block)
            }

            // Determine the direction of travel of the train which depends on the direction of the spread
            // and the original direction of the train in the front block (the block in which the spread started)
            let directionOfTravel: Direction
            if directionOfTrainSameAsSpread {
                directionOfTravel = blockInfo.direction
            } else {
                directionOfTravel = blockInfo.direction.opposite
            }

            let trainInstance = TrainInstance(train.id, directionOfTravel)

            // Update the content of each part
            for part in spreadBlockInfo.parts {
                if part.lastPart, markLastPartAsLocomotive {
                    trainInstance.parts[part.partIndex] = .locomotive
                } else if part.firstPart, markFirstPartAsLocomotive {
                    trainInstance.parts[part.partIndex] = .locomotive
                } else {
                    trainInstance.parts[part.partIndex] = .wagon
                }
            }

            // Update the position, tail or head, using the last part
            if let part = spreadBlockInfo.parts.first(where: { $0.lastPart }) {
                switch lastPartUpdatePosition {
                case .tail:
                    train.positions.tail = .init(blockId: block.id, index: part.partIndex, distance: part.distance, direction: directionOfTravel)
                case .head:
                    train.positions.head = .init(blockId: block.id, index: part.partIndex, distance: part.distance, direction: directionOfTravel)
                }
            }

            block.trainInstance = trainInstance
            block.reservation = Reservation(trainId: train.id, direction: directionOfTravel)

            occupation.append(block, atBeginning: insertAtBeginning)
        })

        if success == false {
            throw LayoutError.cannotReserveAllElements(train: train)
        }
    }
}
