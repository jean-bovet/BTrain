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

extension Train {
    
    static func newLocationWith(trainMovesForward: Bool, currentLocation: TrainLocation, detectedPosition: TrainPosition, direction: Direction, reservation: Train.Reservation) throws -> TrainLocation {
        var newLocation = currentLocation
        
        if trainMovesForward {
            // Train: [back] [front] >>>>
            if currentLocation.back == nil && currentLocation.front == nil {
                newLocation.back = detectedPosition
                newLocation.front = detectedPosition
            } else if let back = currentLocation.back, let front = currentLocation.front {
                if back == front {
                    if try detectedPosition.isAfter(front, reservation: reservation) {
                        // We still don't know exactly where the train is
                        newLocation.back = detectedPosition
                        newLocation.front = detectedPosition
                    } else {
                        // Now we know where the back is, and by definition the front
                        newLocation.back = detectedPosition
                    }
                } else if try back.isBefore(front, reservation: reservation) {
                    if try detectedPosition.isAfter(front, reservation: reservation) {
                        newLocation.front = detectedPosition
                    } else {
                        newLocation.back = detectedPosition
                    }
                } else {
                    // Invalid - the back position cannot be after the front position when the
                    // train moves forward in the direction of the block
                    // TODO: throw
                    fatalError()
                }
            } else {
                // Invalid - both front and back must either be defined or not be defined
                // TODO: throw
                fatalError()
            }
        } else {
            // Train: [front] [back] >>>>
            if currentLocation.back == nil && currentLocation.front == nil {
                newLocation.back = detectedPosition
                newLocation.front = detectedPosition
            } else if let back = currentLocation.back, let front = currentLocation.front {
                if back == front {
                    if try detectedPosition.isAfter(back, reservation: reservation) {
                        // We still don't know exactly where the train is
                        newLocation.back = detectedPosition
                        newLocation.front = detectedPosition
                    } else {
                        // Now we know where the back is, and by definition the front
                        newLocation.front = detectedPosition
                    }
                } else if try back.isAfter(front, reservation: reservation) {
                    if try detectedPosition.isAfter(back, reservation: reservation) {
                        newLocation.back = detectedPosition
                    } else {
                        newLocation.front = detectedPosition
                    }
                } else {
                    // Invalid - the back position cannot be before the front position when the
                    // train moves backwards in the direction of the block
                    // TODO: throw
                    fatalError()
                }
            } else {
                // Invalid - both front and back must either be defined or not be defined
                // TODO: throw
                fatalError()
            }
        }

        return newLocation
    }
    
    /// Returns all the feedbacks that are currently detected in any of the occupied blocks by the train.
    ///
    /// Because a train can have more than one magnet to detect its position (besides under the front locomotive),
    /// we need to take into consideration all the feedback triggers within all the occupied blocks.
    ///
    /// - Returns: array of detected feedback and their position
    static func allActiveFeedbackPositions(train: Train, layout: Layout) -> [FeedbackPosition] {
        var positions = [FeedbackPosition]()
                
        for block in train.occupied.blocks {
            for (feedbackIndex, feedback) in block.feedbacks.enumerated() {
                guard let f = layout.feedbacks[feedback.feedbackId], f.detected else {
                    continue
                }
                
                positions.append(FeedbackPosition(blockId: block.id, index: feedbackIndex))
            }
        }
        
        return positions
    }
    
    /// Returns true if the train is located at the end of the specified block
    /// - Parameters:
    ///   - block: the block
    ///   - train: the train
    /// - Returns: true if train is at the end of block
    static func atEndOfBlock(block: Block, train: Train) throws -> Bool {
        guard let ti = block.trainInstance else {
            throw LayoutError.trainNotFoundInBlock(blockId: block.id)
        }
        if ti.direction == .next {
            if train.directionForward {
                return train.position.front?.index == block.feedbacks.count
            } else {
                return train.position.back?.index == block.feedbacks.count
            }
        } else {
            if train.directionForward {
                return train.position.front?.index == 0
            } else {
                return train.position.back?.index == 0
            }
        }
    }
    
    /// Returns the distance left in the last block in the direction of travel of the train.
    ///
    /// If the train moves forward, the block will be the one where the locomotive is located.
    /// If the train moves backward, the block will be the last occupied one, where the last wagon is located.
    ///
    /// - Parameter train: the train
    /// - Returns: the distance left
    static func distanceLeftInLastBlock(train: Train) -> Double {
        if train.directionForward {
            // Direction of train is forward.
            // Block: [ 0 1 2 3 ]
            // Train:  ----->
            //         b    f
            guard let block = train.occupied.blocks.first else {
                return 0
            }
            
            guard let ti = block.trainInstance else {
                return 0
            }

            guard let length = block.length else {
                return 0
            }

            guard let frontIndex = train.position.front?.index else {
                return 0
            }

            switch ti.direction {
            case .next:
                if frontIndex < block.feedbacks.count {
                    if let feedbackDistance = block.feedbacks[frontIndex].distance {
                        return length - feedbackDistance
                    } else {
                        return 0
                    }
                } else {
                    return 0
                }

            case .previous:
                let p = frontIndex - 1
                if p >= 0, p < block.feedbacks.count {
                    return block.feedbacks[p].distance ?? 0
                } else {
                    return 0
                }
            }
        } else {
            // Direction of train is backward.
            // Block: [ 0 1 2 3 ]
            // Train:  >-----
            //         f    b
            guard let block = train.occupied.blocks.last else {
                return 0
            }
            
            guard let ti = block.trainInstance else {
                return 0
            }

            guard let length = block.length else {
                return 0
            }

            guard let backIndex = train.position.back?.index else {
                return 0
            }

            switch ti.direction {
            case .next:
                if backIndex < block.feedbacks.count {
                    if let feedbackDistance = block.feedbacks[backIndex].distance {
                        return length - feedbackDistance
                    } else {
                        return 0
                    }
                } else {
                    return 0
                }

            case .previous:
                let p = backIndex - 1
                if p >= 0, p < block.feedbacks.count {
                    return block.feedbacks[p].distance ?? 0
                } else {
                    return 0
                }
            }
        }
    }

}
