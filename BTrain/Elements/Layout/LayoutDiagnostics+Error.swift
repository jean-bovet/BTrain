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

extension LayoutDiagnostic {
    enum DiagnosticError: Error, Equatable {
        case feedbackIdAlreadyExists(feedback: Feedback)
        case feedbackNameAlreadyExists(feedback: Feedback)
        case feedbackDuplicateAddress(feedback: Feedback)
        case unusedFeedback(feedback: Feedback)

        case trainIdAlreadyExists(train: Train)
        case trainNameAlreadyExists(train: Train)
        case trainLocomotiveAlreadyUsed(train: Train, locomotive: Locomotive)
        case trainLocomotiveUndefined(train: Train)

        case locIdAlreadyExists(loc: Locomotive)
        case locNameAlreadyExists(loc: Locomotive)
        case locDuplicateAddress(loc: Locomotive)
        case locMissingLength(loc: Locomotive)

        case turnoutIdAlreadyExists(turnout: Turnout)
        case turnoutNameAlreadyExists(turnout: Turnout)
        case turnoutMissingTransition(turnout: Turnout, socket: String)
        case turnoutDuplicateAddress(turnout: Turnout)
        case turnoutSameDoubleAddress(turnout: Turnout)

        case blockIdAlreadyExists(block: Block)
        case blockNameAlreadyExists(block: Block)
        case blockDuplicateFeedback(block: Block, feedback: Feedback)

        case blockMissingTransition(block: Block, socket: String)
        case invalidTransition(transitionId: Identifier<Transition>, socket: Socket)

        case blockMissingLength(block: Block)
        case turnoutMissingLength(turnout: Turnout)
        case trainMissingLength(train: Train)
        case blockFeedbackInvalidDistance(block: Block, feedback: Block.BlockFeedback)
        case blockFeedbackMissingDistance(block: Block, feedbackId: Identifier<Feedback>)

        case invalidRoute(route: Route, error: String)
    }
}

extension LayoutDiagnostic.DiagnosticError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .feedbackIdAlreadyExists(feedback: feedback):
            return "Feedback ID \(feedback.id) (named \(feedback.name)) is used by more than one feedback"
        case let .feedbackNameAlreadyExists(feedback: feedback):
            return "Feedback name \(feedback.name) is used by more than one feedback"
        case let .feedbackDuplicateAddress(feedback: feedback):
            return "The address {deviceID=\(feedback.deviceID), contactID=\(feedback.contactID)} of feedback \(feedback.name) is already used by another feedback"
        case let .unusedFeedback(feedback: feedback):
            return "Feedback \(feedback.name) is not used in the layout"

        case let .blockIdAlreadyExists(block: block):
            return "Block ID \(block.id) (named \(block.name)) is used by more than one block"
        case let .blockNameAlreadyExists(block: block):
            return "Block name \(block.name) is used by more than one block"
        case let .blockDuplicateFeedback(block: block, feedback: feedback):
            return "Block \(block.name) uses feedback \(feedback.name) which is already used by another block"

        case let .turnoutIdAlreadyExists(turnout: turnout):
            return "Turnout ID \(turnout.id) (named \(turnout.name)) is used by more than one turnout"
        case let .turnoutNameAlreadyExists(turnout: turnout):
            return "Turnout name \(turnout.name) is used by more than one turnout"
        case let .turnoutMissingTransition(turnout: turnout, socket: socket):
            return "Turnout \(turnout.name) is missing a transition from socket \(socket)"
        case let .turnoutDuplicateAddress(turnout: turnout):
            if turnout.doubleAddress {
                return "The address of turnout \(turnout.name) (\(turnout.address):\(turnout.address2)) is already used by another turnout"
            } else {
                return "The address of turnout \(turnout.name) (\(turnout.addressValue)) is already used by another turnout"
            }
        case let .turnoutSameDoubleAddress(turnout: turnout):
            return "The addresses of turnout \(turnout.name) (\(turnout.address):\(turnout.address2)) are the same"

        case let .blockMissingTransition(block: block, socket: socket):
            return "Block \(block.name) is missing a transition from socket \(socket)"
        case let .invalidTransition(transitionId: transitionId, socket: socket):
            return "Transition \(transitionId) is not connected via its socket \(socket)"

        case let .blockMissingLength(block: block):
            return "Block \(block.name) does not have a length defined"
        case let .turnoutMissingLength(turnout: turnout):
            return "Turnout \(turnout.name) does not have a length defined"
        case let .blockFeedbackInvalidDistance(block: block, feedback: feedback):
            return "Feedback \(feedback.id) has an invalid distance of \(feedback.distance!) inside block \(block.name) of length \(block.length!)"
        case let .blockFeedbackMissingDistance(block: block, feedbackId: feedbackId):
            return "Block \(block.name) does not have a distance defined for feedback \(feedbackId)"

        case let .trainMissingLength(train: train):
            return "Train \(train.name) does not have a length defined"
        case let .invalidRoute(route: route, error: error):
            return "Route \"\(route.name)\" is invalid and cannot be resolved: \(error)"

        case let .trainIdAlreadyExists(train: train):
            return "Train ID \(train.id) (named \(train.name)) is used by more than one train"
        case let .trainNameAlreadyExists(train: train):
            return "Train \(train.name) is used by more than one train"
        case let .trainLocomotiveUndefined(train: train):
            return "Train \(train.name) does not have a locomotive assigned to it"
        case let .trainLocomotiveAlreadyUsed(train: train, locomotive: locomotive):
            return "Train \(train.name) uses locomotive \(locomotive.name) which is already used by another train"

        case let .locIdAlreadyExists(loc: loc):
            return "Locomotive ID \(loc.id) (named \(loc.name)) is used by more than one locomotive"
        case let .locNameAlreadyExists(loc: loc):
            return "Locomotive \(loc.name) is used by more than one locomotive"
        case let .locDuplicateAddress(loc: loc):
            return "The address of locomotive \(loc.name) (\(loc.address.actualAddress(for: loc.decoder))) is already used by another locomotive"
        case let .locMissingLength(loc: loc):
            return "Locomotive \(loc.name) does not have a length defined"
        }
    }
}
