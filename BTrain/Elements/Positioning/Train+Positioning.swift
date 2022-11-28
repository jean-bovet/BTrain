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
    
    /// Returns true if the train is located at the end of the specified block
    /// - Parameters:
    ///   - block: the block
    ///   - train: the train
    /// - Returns: true if train is at the end of block
    func atEndOfBlock(block: Block) throws -> Bool {
        guard let ti = block.trainInstance else {
            throw LayoutError.trainNotFoundInBlock(blockId: block.id)
        }
        if ti.direction == .next {
            if directionForward {
                return position.front?.index == block.feedbacks.count
            } else {
                return position.back?.index == block.feedbacks.count
            }
        } else {
            if directionForward {
                return position.front?.index == 0
            } else {
                return position.back?.index == 0
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
    func distanceLeftInLastBlock() -> Double {        
        if directionForward {
            // Direction of train is forward.
            // Block: [ 0 1 2 3 ]
            // Train:  ----->
            //         b    f
            // TODO: use frontBlock instead?
            guard let block = occupied.blocks.first else {
                return 0
            }
            
            guard let ti = block.trainInstance else {
                return 0
            }
            
            guard let length = block.length else {
                return 0
            }
            
            guard let frontIndex = position.front?.index else {
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
            // TODO: use frontBlock instead?
            guard let block = occupied.blocks.last else {
                return 0
            }
            
            guard let ti = block.trainInstance else {
                return 0
            }
            
            guard let length = block.length else {
                return 0
            }
            
            guard let backIndex = position.back?.index else {
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
