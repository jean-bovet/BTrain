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
    func hasReachedStationOrDestination(_ route: Route?, _ block: Block) -> Bool {
        if let route = route {
            switch route.mode {
            case let .automaticOnce(destination):
                if !hasReached(block: block, destination: destination) {
                    return false
                }
            case .fixed, .automatic:
                if block.category != .station {
                    return false
                }
            }
        } else {
            if block.category != .station {
                return false
            }
        }

        // Check that the train is not in the first block of the route in which case
        // it should not stop at all, otherwise a train will never leave its station
        guard routeStepIndex != startRouteIndex || startRouteIndex == nil else {
            return false
        }

        return true
    }

    func hasReached(block: Block, destination: Destination) -> Bool {
        guard block.id == destination.blockId else {
            return false
        }

        if let direction = destination.direction {
            return direction == block.trainInstance?.direction
        } else {
            return true
        }
    }

    /// Returns the distance left in the front block in the direction of travel of the train.
    ///
    /// - Parameter frontBlock: the block at the front of the train
    /// - Returns: the distance left
    func distanceLeftInFrontBlock(frontBlock: Block) -> Double {
        guard let ti = frontBlock.trainInstance else {
            return 0
        }

        guard let length = frontBlock.length else {
            return 0
        }

        let feedbackIndex: Int
        if directionForward {
            // Direction of train is forward.
            // Block:    [ | | | ]>
            // Feedbacks:  0 1 2
            // Index:     0 1 2 3
            // Train:  ----->
            //         t    h
            guard let headIndex = positions.head?.index else {
                return 0
            }

            if ti.direction == .next {
                feedbackIndex = headIndex
            } else {
                feedbackIndex = headIndex - 1
            }
        } else {
            // Direction of train is backward.
            // Block:    [ | | | ]>
            // Feedbacks:  0 1 2
            // Index:     0 1 2 3
            // Train:  >-----
            //         h    t
            guard let tailIndex = positions.tail?.index else {
                return 0
            }

            if ti.direction == .next {
                feedbackIndex = tailIndex
            } else {
                feedbackIndex = tailIndex - 1
            }
        }

        switch ti.direction {
        case .next:
            if feedbackIndex < 0 {
                return length
            } else if feedbackIndex < frontBlock.feedbacks.count {
                if let feedbackDistance = frontBlock.feedbacks[feedbackIndex].distance {
                    return length - feedbackDistance
                } else {
                    return 0
                }
            } else {
                return 0
            }

        case .previous:
            if feedbackIndex < 0 {
                return 0
            } else if feedbackIndex < frontBlock.feedbacks.count {
                return frontBlock.feedbacks[feedbackIndex].distance ?? 0
            } else {
                return length
            }
        }
    }
}
