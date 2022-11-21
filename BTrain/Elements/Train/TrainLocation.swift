//
//  TrainLocation.swift
//  BTrain
//
//  Created by Jean Bovet on 11/19/22.
//

import Foundation

// Definitions:
// - A block contains one or more feedback identified by an index starting at 0 and growing
//   in the natural direction of the block (see Feedback Index in the diagram below).
// - A position within the block is identified by an index, growing in the natural direction
//   of the block (see Position Index in the diagram below).
// - A train has a way to detect its locomotive (usually a magnet under the locomotive that will
//   activate a reed feedback). This detects what we call the "Front Position".
// - A train, optionally, has a way to detect the last wagon (in order to move backwards). This
//   detects what we call the "Back Position".
//                                                                                F
//                  B ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ r
//                  a │                 │ │                 │ │                 │ o
//                  c │      wagon      │ │      wagon      │ │   locomotive    │ n
//                  k │                 │ │                 │ │                 │ t
//                    └─────────────────┘ └─────────────────┘ └─────────────────┘
//    Back Position ──────────▶  ▼                                       ▼   ◀─────────── Front Position
//
//                            ╲       ██            ██            ██
//                             ╲      ██            ██            ██
//                      ────────■─────██────────────██────────────██────────────▶
//                             ╱   0  ██     1      ██     2      ██     3
//                            ╱       ██            ██            ██     ▲
//                                    0             1             2      │
//                                                  ▲                    │
//                                                  │                    │
//                                                  │                    │
//
//                                           Feedback Index       Position Index
//
// Let's consider a train moving forward that occupies 3 blocks A, B and C.
// The train forward position, identifier by "f", is located under the locomotive
// at the front of the train. This position is associated with a magnet under the locomotive that
// triggers a feedback each time the locomotive moves over a feedback.
//
// The following diagram shows the train with its front position in (Block C, index 0) and its
// back position in (Block A, index 0).
//      b                            f
//      ▼                            ▼
//      0 | 1 | 2      0| 1 | 2     0 | 1 | 2
//     ┌─────────┐   ┌─────────┐   ┌─────────┐
//     │ ■■■■■■■ │──▶│ ■■■■■■■ │──▶│ ▶       │
//     └─────────┘   └─────────┘   └─────────┘
//       A             B            C
//
// The following diagram shows the train moving in the direction opposite to the natural direction of block C.
// Notice that in this situation, the front position is (Block C, index 2) and back position stays the same.
//
//      b                           f
//      ▼                           ▼
//      0 | 1 | 2      0| 1 | 2     2 | 1 | 0
//     ┌─────────┐   ┌─────────┐   ┌─────────┐
//     │ ■■■■■■■ │──▶│ ■■■■■■■ │──▶│ ▶       │
//     └─────────┘   └─────────┘   └─────────┘
//       A             B            C
//
// The following diagram shows the train moving backwards (that is, the locomotive is pushing the wagons instead of pulling)
// with its front position in (Block A, index 0) and back position in (Block C, index 0). By convention, the front
// position is always at the "front" of the train when it moves forward and the back position is at the last wagon of the
// train when it moves forward.
//      f                            b
//      ▼                            ▼
//      0 | 1 | 2      0| 1 | 2     0 | 1 | 2
//     ┌─────────┐   ┌─────────┐   ┌─────────┐
//     │ ▶■■■■■■ │──▶│ ■■■■■■■ │──▶│ ■       │
//     └─────────┘   └─────────┘   └─────────┘
//       A             B            C
//
// The following diagram shows the train moving backwards and entering block C in the direction opposite to the natural direction
// of block C. The front position is (Block A, index 0) and back position is (Block C, index 2).
//      f                            b
//      ▼                            ▼
//      0 | 1 | 2      0| 1 | 2     2 | 1 | 0
//     ┌─────────┐   ┌─────────┐   ┌─────────┐
//     │ ▶■■■■■■ │──▶│ ■■■■■■■ │──▶│ ■       │
//     └─────────┘   └─────────┘   └─────────┘
//       A             B            C
                                         
/// The position of a train includes the block in which that position is located, the index of the position (relative to the natural direction of the block
/// and the feedbacks inside the block) and finally the direction of travel of the train within the block.
///
/// Note: the direction of travel of the train is used to determine if a position is before (or after) another position in the same block.
struct TrainPosition: Equatable, Codable, CustomStringConvertible {
    
    /// The index of the block in which that position is located.
    /// Note: the index is increasing in the direction of travel of the train
    var block: Int
    
    /// The index of the position within the block.
    /// Note: the index is increasing in the natural direction of the block (.next)
    var index: Int
        
    /// The direction of travel of the train within the block. The natural direction is .next
    var direction: Direction = .next
    
    var description: String {
        "\(index)\(direction)"
    }

    static func >(lhs: TrainPosition, rhs: TrainPosition) -> Bool {
        if lhs.block > rhs.block {
            return true
        } else if lhs.block < rhs.block {
            return false
        } else {
            // Same block. Now the direction matters to compare
            if lhs.direction == .next {
                return lhs.index > rhs.index
            } else {
                return lhs.index < rhs.index
            }
        }
    }

    static func <(lhs: TrainPosition, rhs: TrainPosition) -> Bool {
        if lhs.block < rhs.block {
            return true
        } else if lhs.block > rhs.block {
            return false
        } else {
            // Same block. Now the direction matters to compare
            if lhs.direction == .next {
                return lhs.index < rhs.index
            } else {
                return lhs.index > rhs.index
            }
        }
    }
    
}

/// The train location consists of two positions: a front position and a back position.
///
/// Notes:
/// - Each of these positions correspond to a magnet that triggers a feedback in the layout.
/// - A train that only moves forward needs only one magnet at the front of the train.
/// - A train that moves forward and backward needs a magnet at the front and the back of the train
struct TrainLocation: Equatable, Codable, CustomStringConvertible {
    
    /// The position at the front of the train (where the locomotive is located)
    var front: TrainPosition?
    
    /// The position at the back of the train (where the last wagon is located)
    var back: TrainPosition?
    
    var description: String {
        if let front = front, let back = back {
            return "\(front)-\(back)"
        } else if let front = front {
            return "\(front)-?"
        } else if let back = back {
            return "?-\(back)"
        } else {
            return "?-?"
        }
    }
    
    struct FeedbackPosition {
        let block: Int
        let index: Int
        var direction: Direction = .next
        
        var trainPosition: TrainPosition {
            switch direction {
            case .previous:
                return TrainPosition(block: block, index: index, direction: direction)

            case .next:
                return TrainPosition(block: block, index: index + 1, direction: direction)
            }
        }
    }
    
    static func newLocationWith(trainMovesForward: Bool, currentLocation: TrainLocation, feedbackIndex: FeedbackPosition) -> TrainLocation {
//        let strict = strictRouteFeedbackStrategy // TODO

        var newLocation = currentLocation
        let detectedPosition = feedbackIndex.trainPosition

        if trainMovesForward {
            // Train: [back] [front] >>>>
            if currentLocation.back == nil && currentLocation.front == nil {
                newLocation.back = detectedPosition
                newLocation.front = detectedPosition
            } else if let back = currentLocation.back, let front = currentLocation.front {
                if back == front {
                    if detectedPosition > front {
                        // We still don't know exactly where the train is
                        newLocation.back = detectedPosition
                        newLocation.front = detectedPosition
                    } else {
                        // Now we know where the back is, and by definition the front
                        newLocation.back = detectedPosition
                    }
                } else if back < front {
                    if detectedPosition > front {
                        newLocation.front = detectedPosition
                    } else {
                        newLocation.back = detectedPosition
                    }
                } else {
                    // Invalid - the back position cannot be after the front position when the
                    // train moves forward in the direction of the block
                    fatalError()
                }
            } else {
                // Invalid - both front and back must either be defined or not be defined
                fatalError()
            }
        } else {
            // Train: [front] [back] >>>>
            if currentLocation.back == nil && currentLocation.front == nil {
                newLocation.back = detectedPosition
                newLocation.front = detectedPosition
            } else if let back = currentLocation.back, let front = currentLocation.front {
                if back == front {
                    if detectedPosition > back {
                        // We still don't know exactly where the train is
                        newLocation.back = detectedPosition
                        newLocation.front = detectedPosition
                    } else {
                        // Now we know where the back is, and by definition the front
                        newLocation.front = detectedPosition
                    }
                } else if back > front {
                    if detectedPosition > back {
                        newLocation.back = detectedPosition
                    } else {
                        newLocation.front = detectedPosition
                    }
                } else {
                    // Invalid - the back position cannot be after the front position when the
                    // train moves forward in the direction of the block
                    fatalError()
                }
            } else {
                // Invalid - both front and back must either be defined or not be defined
                fatalError()
            }
        }

        return newLocation
    }

}

struct TrainLocationHelper {
    
    /// Returns all the feedbacks that are currently detected in any of the occupied blocks by the train.
    ///
    /// Because a train can have more than one magnet to detect its position (besides under the front locomotive),
    /// we need to take into consideration all the feedback triggers within all the occupied blocks.
    ///
    /// - Returns: array of detected feedback and their position
    static func allActiveFeedbackPositions(train: Train, layout: Layout) -> [TrainLocation.FeedbackPosition] {
        guard let trainInstance = train.occupied.blocks.first?.trainInstance else {
            return []
        }
        
        var positions = [TrainLocation.FeedbackPosition]()
                
        for (blockIndex, block) in train.occupied.blocks.enumerated() {
            for (feedbackIndex, feedback) in block.feedbacks.enumerated() {
                guard let f = layout.feedbacks[feedback.feedbackId], f.detected else {
                    continue
                }
                
                positions.append(TrainLocation.FeedbackPosition(block: blockIndex, index: feedbackIndex, direction: trainInstance.direction))
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
                return train.position.front?.index == block.feedbacks.count + 1
            } else {
                return train.position.back?.index == block.feedbacks.count + 1
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
        guard let length = train.length else {
            return 0
        }

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
