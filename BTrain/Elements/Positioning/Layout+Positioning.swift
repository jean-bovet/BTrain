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
    /// Sets the train into the specified block, at the specified position and direction of travel in the block.
    ///
    /// - Parameters:
    ///   - train: the train
    ///   - positions: the positions
    func setTrainPositions(_ train: Train, _ positions: TrainPositions) throws {
        train.positions = positions

        try freeElements(train: train)
        try occupyBlocksWith(train: train)
    }

    // This method reserves and occupies all the necessary blocks (and parts of the block) to fit
    // the specified train with all its length, taking into account the length of each block.
    func occupyBlocksWith(train: Train) throws {
        try LayoutOccupation.occupyBlocksWith(train: train, layout: self)
    }

    // This methods frees all the reserved elements
    func freeElements(train: Train) throws {
        train.leading.clear()
        train.occupied.clear()

        blocks.elements
            .filter { $0.reservation?.trainId == train.id }
            .forEach { block in
                block.reservation = nil
                block.trainInstance = nil
            }
        turnouts.elements.filter { $0.reserved?.train == train.id }.forEach { $0.reserved = nil; $0.train = nil }
        transitions.elements.filter { $0.reserved == train.id }.forEach { $0.reserved = nil; $0.train = nil }
    }

    /// Returns all the feedbacks that are currently detected in any of the occupied blocks by the train.
    ///
    /// Because a train can have more than one magnet to detect its position (besides under the front locomotive),
    /// we need to take into consideration all the feedback triggers within all the occupied blocks.
    ///
    /// - Returns: array of detected feedback and their position
    func allOccupiedBlocksActiveFeedbackPositions(train: Train) throws -> [FeedbackPosition] {
        var positions = [FeedbackPosition]()

        for block in train.occupied.blocks {
            for (feedbackIndex, feedback) in block.feedbacks.enumerated() {
                guard let f = feedbacks[feedback.feedbackId], f.detected else {
                    continue
                }

                guard let fd = feedback.distance else {
                    throw LayoutError.feedbackDistanceNotSet(feedback: feedback)
                }

                guard let direction = block.trainInstance?.direction else {
                    // Note: this should not happen because all the feedback are in occupied block
                    // which, by definition, have a train (and a direction) in them.
                    throw LayoutError.directionNotFound(blockId: block.id)
                }

                let fp = FeedbackPosition(block: block, feedback: f, feedbackIndex: feedbackIndex, distance: fd, direction: direction)
                positions.append(fp)
            }
        }

        return positions
    }
    
    enum FeedbackType {
        case brake
        case stop
    }
    
    /// Returns true if the front of the train is after the specified feedback type
    ///
    /// - Parameters:
    ///   - train: the train
    ///   - type: the type of feedback
    /// - Returns: true if the front of the train is past the specified feedback type, false otherwise
    // TODO: add unit test for this method only
    func isTrainLocatedAfterFeedback(train: Train, type: FeedbackType) throws -> Bool {
        guard let frontBlock = blocks[train.frontBlockId] else {
            return false
        }

        guard let trainInstance = frontBlock.trainInstance else {
            return false
        }

        let direction = trainInstance.direction

        let feedbackId: Identifier<Feedback>?
        switch type {
        case .brake:
            feedbackId = frontBlock.brakeFeedback(for: direction)
        case .stop:
            feedbackId = frontBlock.stopFeedback(for: direction)
        }

        guard let feedbackId = feedbackId else {
            BTLogger.warning("\(train): ⚠️ feedback \(type) not found in \(frontBlock)")
            return false
        }
        
        guard let bf = frontBlock.feedbacks.first(where: {$0.feedbackId == feedbackId }) else {
            throw LayoutError.feedbackNotFound(feedbackId: feedbackId)
        }

        guard let bfDistance = bf.distance else {
            throw LayoutError.feedbackDistanceNotSet(feedback: bf)
        }
        
        let frontDistance: Double
        if train.directionForward {
            guard let headDistance = train.positions.head?.distance else {
                throw LayoutError.headPositionNotSpecified(position: train.positions)
            }
            frontDistance = headDistance
        } else {
            guard let tailDistance = train.positions.tail?.distance else {
                throw LayoutError.tailPositionNotSpecified(position: train.positions)
            }
            frontDistance = tailDistance
        }
        
        if direction == .next {
            return frontDistance > bfDistance
        } else {
            return frontDistance < bfDistance
        }
    }
    
}
