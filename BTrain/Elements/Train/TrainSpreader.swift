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
    typealias TransitionCallbackBlock = (Transition) throws -> Void
    typealias TurnoutCallbackBlock = (ElementVisitor.TurnoutInfo) throws -> Void

    let layout: Layout
    let visitor: ElementVisitor

    init(layout: Layout) {
        self.layout = layout
        visitor = ElementVisitor(layout: layout)
    }

    struct SpreadBlockPartInfo {
        let partIndex: Int
        let distance: Double
        let firstPart: Bool
        var lastPart: Bool = false
        
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
            return .init(partIndex: partIndex, distance: distance, firstPart: firstPart)
        }

    }
    
    struct SpreadBlockInfo {
        let block: ElementVisitor.BlockInfo
        let parts: [SpreadBlockPartInfo]
    }
        
    typealias BlockPartCallbackBlock = (SpreadBlockInfo) throws -> Void
    
    /// Visit all the elements that a train occupies - transitions, turnouts and blocks - starting
    /// with the front block (the block at the front of the train in its direction of travel) and going backwards.
    /// Updates the parts of the train in each block as well as the "tail" position of the train.
    ///
    /// - Parameters:
    ///   - blockId: <#blockId description#>
    ///   - distance: <#distance description#>
    ///   - direction: <#direction description#>
    ///   - lengthOfTrain: <#lengthOfTrain description#>
    ///   - transitionCallback: <#transitionCallback description#>
    ///   - turnoutCallback: <#turnoutCallback description#>
    ///   - blockCallback: <#blockCallback description#>
    /// - Returns: <#description#>
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
                        if cursor < fbDistance, remainingTrainLength >= 0 {
                            let u = fbDistance - cursor
                            assert(u >= 0)
                            remainingTrainLength -= u
                            cursor = fbDistance
                            parts.append(SpreadBlockPartInfo.info(firstPart: index == 0 && parts.isEmpty, partIndex: findex, remainingTrainLength: remainingTrainLength, feedbackDistance: fbDistance, direction: .next))
                        }
                    }

                    if cursor <= blockLength, remainingTrainLength >= 0 {
                        let u = blockLength - cursor
                        assert(u >= 0)
                        remainingTrainLength -= u
                        parts.append(SpreadBlockPartInfo.info(firstPart: index == 0 && parts.isEmpty, partIndex: feedbacks.count, remainingTrainLength: remainingTrainLength, feedbackDistance: blockLength, direction: .next))
                    }
                    
                    if parts.count > 0 {
                        parts[parts.count - 1].lastPart = remainingTrainLength <= 0
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
                        if cursor > fbDistance, remainingTrainLength >= 0 {
                            let u = cursor - fbDistance
                            assert(u >= 0)
                            remainingTrainLength -= u
                            cursor = fbDistance
                            parts.append(SpreadBlockPartInfo.info(firstPart: index == 0 && parts.isEmpty, partIndex: findex+1, remainingTrainLength: remainingTrainLength, feedbackDistance: fbDistance, direction: .previous))
                        }
                    }

                    if cursor >= 0, remainingTrainLength >= 0 {
                        let u = cursor - 0
                        assert(u >= 0)
                        remainingTrainLength -= u
                        parts.append(SpreadBlockPartInfo.info(firstPart: index == 0 && parts.isEmpty, partIndex: 0, remainingTrainLength: remainingTrainLength, feedbackDistance: 0, direction: .previous))
                    }

                    if parts.count > 0 {
                        parts[parts.count - 1].lastPart = remainingTrainLength <= 0
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
    
}
