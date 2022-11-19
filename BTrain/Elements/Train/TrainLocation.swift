//
//  TrainLocation.swift
//  BTrain
//
//  Created by Jean Bovet on 11/19/22.
//

import Foundation

/// The position of a train includes the block in which that position is located, the index of the position (relative to the natural direction of the block
/// and the feedbacks inside the block) and finally the direction of travel of the train within the block.
///
/// Note: the direction of travel of the train is used to determine if a position is before (or after) another position in the same block.
struct TrainPosition: Equatable {
    
    /// The index of the block in which that position is located.
    /// Note: the index is increasing in the direction of travel of the train
    var block: Int
    
    /// The index of the position within the block.
    /// Note: the index is increasing in the natural direction of the block (.next)
    var index: Int
        
    /// The direction of travel of the train within the block. The natural direction is .next
    var direction: Direction = .next
    
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
struct TrainLocation: CustomStringConvertible {
    
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

