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

/// The event that the simulated train can emit
enum SimulatorTrainEvent: Equatable {
    case distanceUpdated
    case movedToNextBlock(block: Block)
    case movedToNextTurnout(turnout: Turnout)
    case triggerFeedback(feedback: Feedback)
}

protocol SimulatorTrainDelegate: AnyObject {
    func trainDidChange(event: SimulatorTrainEvent)
}

/// This class simulates a train in the layout by moving it from block to block
/// using the actual speed of the train.
final class SimulatorTrain: ObservableObject, Element {
    
    let name: String
    let id: Identifier<Train>
    let loc: SimulatorLocomotive
    let layout: Layout
    
    weak var delegate: SimulatorTrainDelegate?
        
    internal init(id: Identifier<Train>, name: String, loc: SimulatorLocomotive, layout: Layout, delegate: SimulatorTrainDelegate?) {
        self.id = id
        self.name = name
        self.loc = loc
        self.layout = layout
        self.delegate = delegate
    }
    
    /// Invoke this method to update the train position given the speed and duration of the speed.
    ///
    /// - Parameters:
    ///   - speed: the speed of the train
    ///   - duration: the duration of the speed, which is used to compute the distance the train has traveled
    func update(speed: SpeedKph, duration: TimeInterval) throws {
        try updateDistance(speed: speed, duration: duration)
        if try isInsideElement() {
            try triggerBlockFeedback()
        } else {
            try moveToNextElement()
        }
    }
    
    private func updateDistance(speed: SpeedKph, duration: TimeInterval) throws {
        let delta = LayoutSpeed.distance(atSpeed: speed, forDuration: duration)
        if let block = loc.block {
            if block.direction == .next {
                loc.distance += delta
            } else {
                loc.distance -= delta
            }
        } else if loc.turnout != nil {
            loc.distance += delta
        } else {
            throw SimulatorTrainError.missingBlockAndTurnout
        }
                
        debug("updated distance to \(loc.distance.distanceString) with delta \(delta.distanceString) for \(duration.durationString) at \(speed.speedString).")
        delegate?.trainDidChange(event: .distanceUpdated)
    }
    
    private func isInsideElement() throws -> Bool {
        let inside: Bool
        if let block = loc.block {
            guard let blockLength = block.block.length else {
                throw SimulatorTrainError.missingBlockLength(block: block.block)
            }
            if block.direction == .next {
                inside = loc.distance <= blockLength
            } else {
                inside = loc.distance >= 0
            }
        } else if let turnout = loc.turnout {
            guard let turnoutLength = turnout.turnout.length else {
                throw SimulatorTrainError.missingTurnoutLength(turnout: turnout.turnout)
            }

            inside = loc.distance < turnoutLength
        } else {
            throw SimulatorTrainError.missingBlockAndTurnout
        }

        return inside
    }
    
    /// Keep track of the last triggered feedback in order to only trigger it once,
    /// after the train has moved past it.
    private var lastTriggeredFeedbackId: Identifier<Feedback>?
    
    private func triggerBlockFeedback() throws {
        guard let block = loc.block else {
            return
        }
        
        guard let blockFeedback = try currentBlockFeedback() else {
            return
        }
        
        if let feedback = layout.feedbacks[blockFeedback.feedbackId] {
            // Only trigger the feedback if it hasn't yet been triggered
            if lastTriggeredFeedbackId != feedback.id {
                lastTriggeredFeedbackId = feedback.id
                debug("trigger feedback \(feedback.name) at \(blockFeedback.distanceString) in \(block.block.name).")
                delegate?.trainDidChange(event: .triggerFeedback(feedback: feedback))
            }
        } else {
            throw SimulatorTrainError.feedbackNotFound(feedbackId: blockFeedback.feedbackId)
        }
    }
    
    /// Returns the feedback that is just before the train's position
    /// - Returns: the feedback or nil if no feedback found
    private func currentBlockFeedback() throws -> Block.BlockFeedback? {
        guard let block = loc.block else {
            return nil
        }
        
        let feedbacks = block.block.feedbacks
        if block.direction == .next {
            for f in feedbacks.reversed() {
                if let distance = f.distance {
                    if distance <= loc.distance {
                        return f
                    }
                } else {
                    throw SimulatorTrainError.missingFeedbackDistance(feedback: f)
                }
            }
        } else {
            for f in feedbacks {
                if let distance = f.distance {
                    if distance >= loc.distance {
                        return f
                    }
                } else {
                    throw SimulatorTrainError.missingFeedbackDistance(feedback: f)
                }
            }
        }
        
        return nil
    }
    
    private func moveToNextElement() throws {
        lastTriggeredFeedbackId = nil

        if let block = loc.block {
            let fromSocket: Socket
            if block.direction == .next {
                fromSocket = block.block.next
            } else {
                fromSocket = block.block.previous
            }
            if let transition = try layout.transition(from: fromSocket) {
                debug("follow \(transition.description(layout))")
                try moveToNextElement(transition: transition)
            } else {
                throw SimulatorTrainError.transitionNotFoundFromSocket(socket: fromSocket)
            }
        } else if let turnout = loc.turnout {
            if let transition = try layout.transition(from: turnout.toSocket) {
                debug("follow \(transition.description(layout))")
                try moveToNextElement(transition: transition)
            } else {
                throw SimulatorTrainError.transitionNotFoundFromSocket(socket: turnout.toSocket)
            }
        } else {
            throw SimulatorTrainError.missingBlockAndTurnout
        }
    }
    
    private func moveToNextElement(transition: Transition) throws {
        let toSocket = transition.b
        guard let toSocketId = toSocket.socketId else {
            throw SimulatorTrainError.missingSocketId(socket: toSocket)
        }
        if let nextBlockId = toSocket.block {
            if let nextBlock = layout.blocks[nextBlockId] {
                let direction: Direction = toSocketId == nextBlock.previous.socketId ? .next : .previous
                loc.block = .init(block: nextBlock, direction: direction, directionForward: loc.directionForward)
                loc.turnout = nil
                loc.distance = direction == .next ? 0 : (nextBlock.length ?? 0)
                debug("moved to block \(nextBlock.name) in \(direction).")
                delegate?.trainDidChange(event: .movedToNextBlock(block: nextBlock))
            }
        } else if let nextTurnoutId = toSocket.turnout {
            if let nextTurnout = layout.turnouts[nextTurnoutId] {
                debug("moved to turnout \(nextTurnout.name).")
                delegate?.trainDidChange(event: .movedToNextTurnout(turnout: nextTurnout))

                loc.block = nil
                loc.distance = 0
                let turnoutEntrySocket = nextTurnout.socket(toSocketId)
                if let turnoutExitSocketId = nextTurnout.socketId(fromSocketId: toSocketId, withState: nextTurnout.actualState) {
                    loc.turnout = .init(turnout: nextTurnout, fromSocket: turnoutEntrySocket, toSocket: nextTurnout.socket(turnoutExitSocketId))
                } else {
                    throw SimulatorTrainError.socketIdNotFoundInTurnout(turnout: nextTurnout, socketId: toSocketId, state: nextTurnout.actualState)
                }
            }
        } else {
            throw SimulatorTrainError.missingBlockAndTurnout
        }
    }
    
    private func debug(_ msg: String) {
        BTLogger.simulator.debug("\(self.name, privacy: .public) [\(self.loc.locationString, privacy: .public)]: \(msg, privacy: .public)")
    }
}

private extension SimulatorLocomotive {
    
    var locationString: String {
        if let block = block {
            return "\(block.block.name)"
        } else if let turnout = turnout {
            return "\(turnout.turnout.name)"
        } else {
            return "?"
        }
    }
}

private extension Block.BlockFeedback {
    
    var distanceString: String {
        if let distance = distance {
            return distance.distanceString
        } else {
            return "n/a"
        }
    }
}
