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

enum SimulatorTrainError: Error {
    case missingBlockAndTurnout
    case missingBlockLength(block: Block)
    case missingTurnoutLength(turnout: Turnout)
    case feedbackNotFound(feedbackId: Identifier<Feedback>)
    case missingFeedbackDistance(feedback: Block.BlockFeedback)
    case transitionNotFoundFromSocket(socket: Socket)
    case missingSocketId(socket: Socket)
    case socketIdNotFoundInTurnout(turnout: Turnout, socketId: SocketId, state: Turnout.State)
}

extension SimulatorTrainError: LocalizedError {
    
    var errorDescription: String? {
        switch self {
        case .missingBlockAndTurnout:
            return "Missing both block and turnout"
        case .missingBlockLength(block: let block):
            return "Missing block length for \(block.name)"
        case .missingTurnoutLength(turnout: let turnout):
            return "Missing turnout length for \(turnout.name)"
        case .feedbackNotFound(feedbackId: let feedbackId):
            return "Feedback \(feedbackId) not found"
        case .missingFeedbackDistance(feedback: let feedback):
            return "Feedback distance missing for \(feedback.feedbackId)"
        case .transitionNotFoundFromSocket(socket: let socket):
            return "No transition found out of socket \(socket)"
        case .missingSocketId(socket: let socket):
            return "Missing socket ID for \(socket)"
        case .socketIdNotFoundInTurnout(turnout: let turnout, socketId: let socketId, state: let state):
            return "Socket ID not found in turnout \(turnout.name) from socket \(socketId) for \(state)"
        }
    }
}
