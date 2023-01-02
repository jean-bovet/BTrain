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
    
    enum UpdatePosition {
        case tail
        case head
    }
    
    /// Specify which position, tail or head, of the train must be updated when the last part of the spread is reached
    let lastPartUpdatePosition: UpdatePosition
    
    init(train: Train) throws {
        guard let frontBlock = train.block else {
            throw LayoutError.trainNotAssignedToABlock(train: train)
        }
        
        guard let trainInstance = frontBlock.trainInstance else {
            throw LayoutError.trainNotFoundInBlock(blockId: frontBlock.id)
        }

        guard let trainLength = train.length else {
            // TODO: throw
            fatalError()
        }

        if train.directionForward {
            if let head = train.positions.head {
                // When moving forward, the head position is used
                blockId = head.blockId
                distance = head.distance
                lengthOfTrain = trainLength
                markFirstPartAsLocomotive = true
                markLastPartAsLocomotive = false
                lastPartUpdatePosition = .tail
                directionOfSpread = trainInstance.direction.opposite
            } else {
                throw LayoutError.frontPositionNotSpecified(position: train.positions)
            }
        } else {
            if let tail = train.positions.tail {
                // When moving backwards, prefer to use the tail position if available
                blockId = tail.blockId
                distance = tail.distance
                if trainInstance.direction == .next {
                    // [ >------- ]>
                    //   h      t
                    //   <------- (visit direction)
                    lengthOfTrain = trainLength
                    markFirstPartAsLocomotive = false
                    markLastPartAsLocomotive = true
                    lastPartUpdatePosition = .head
                    directionOfSpread = trainInstance.direction.opposite
                } else {
                    // [ -------< ]>
                    //   t      h
                    lengthOfTrain = trainLength
                    markFirstPartAsLocomotive = false
                    markLastPartAsLocomotive = true
                    lastPartUpdatePosition = .head
                    directionOfSpread = trainInstance.direction.opposite
                }
            } else if let head = train.positions.head {
                // If the tail position is not available, the front position is used
                blockId = head.blockId
                distance = head.distance
                if trainInstance.direction == .next {
                    // [ >------- ]>
                    //   h      t
                    lengthOfTrain = trainLength
                    markFirstPartAsLocomotive = true
                    markLastPartAsLocomotive = false
                    lastPartUpdatePosition = .tail
                    directionOfSpread = trainInstance.direction
                } else {
                    // [ -------< ]>
                    //   t      h
                    lengthOfTrain = trainLength
                    markFirstPartAsLocomotive = true
                    markLastPartAsLocomotive = false
                    lastPartUpdatePosition = .tail
                    directionOfSpread = trainInstance.direction
                }
            } else {
                // TODO: throw
                fatalError()
            }
        }
                
        assert(frontBlock.id == blockId)
    }
    
    func occupyBlocksWith(train: Train, layout: Layout) throws {
        guard let frontBlock = train.block else {
            throw LayoutError.trainNotAssignedToABlock(train: train)
        }
        
        guard let trainInstance = frontBlock.trainInstance else {
            throw LayoutError.trainNotFoundInBlock(blockId: frontBlock.id)
        }

        // When moving forward, the frontBlock is the block where the locomotive is located.
        // When moving backward, the frontBlock is the block where the last wagon is located.
        // --> now when moving backward, the frontBlock can be the block where the locomotive is located
        // if there are no magnet at the tail of the train!
        let occupation = train.occupied
        occupation.clear()
        
        let spreader = TrainSpreader(layout: layout)
        let success = try spreader.spread(blockId: blockId, distance: distance, direction: directionOfSpread, lengthOfTrain: lengthOfTrain, transitionCallback: { transition in
            guard transition.reserved == nil else {
                throw LayoutError.transitionAlreadyReserved(train: train, transition: transition)
            }
            transition.reserved = train.id
            transition.train = train.id
            occupation.append(transition)
        }, turnoutCallback: { turnoutInfo in
            let turnout = turnoutInfo.turnout
            
            guard turnout.reserved == nil else {
                throw LayoutError.turnoutAlreadyReserved(turnout: turnout)
            }
            turnout.reserved = Turnout.Reservation(train: train.id, sockets: turnoutInfo.sockets)
            turnout.train = train.id
            occupation.append(turnout)
        }, blockCallback: { spreadBlockInfo in
            let blockInfo = spreadBlockInfo.blockInfo
            let block = blockInfo.block
            guard block.reservation == nil || block == train.block else {
                throw LayoutError.blockAlreadyReserved(block: block)
            }
            
            // Determine the direction of travel of the train which depends on the direction of the spread
            // and the original direction of the train in the front block (the block in which the spread started)
            let directionOfTravel: Direction
            if trainInstance.direction == directionOfSpread {
                directionOfTravel = blockInfo.direction
            } else {
                directionOfTravel = blockInfo.direction.opposite
            }
            
            let trainInstance = TrainInstance(train.id, directionOfTravel)
            
            // Update the parts
            for part in spreadBlockInfo.parts {
                if part.lastPart && markLastPartAsLocomotive {
                    trainInstance.parts[part.partIndex] = .locomotive
                } else if part.firstPart && markFirstPartAsLocomotive {
                    trainInstance.parts[part.partIndex] = .locomotive
                } else {
                    trainInstance.parts[part.partIndex] = .wagon
                }
            }
            
            // Update the position, tail or head, using the last part
            if let part = spreadBlockInfo.parts.first(where: { $0.lastPart }) {
                switch lastPartUpdatePosition {
                case .tail:
                    train.positions.tail = .init(blockId: block.id, index: part.partIndex, distance: part.distance)
                case .head:
                    train.positions.head = .init(blockId: block.id, index: part.partIndex, distance: part.distance)
                }
            }
            
            block.trainInstance = trainInstance
            block.reservation = Reservation(trainId: train.id, direction: directionOfTravel)
            
            occupation.append(block)
        })
        
        if success == false {
            throw LayoutError.cannotReserveAllElements(train: train)
        }
    }
}
