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
        case .feedbackIdAlreadyExists(feedback: let feedback):
            return "Feedback ID \(feedback.id) (named \(feedback.name)) is used by more than one feedback"
        case .feedbackNameAlreadyExists(feedback: let feedback):
            return "Feedback name \(feedback.name) is used by more than one feedback"
        case .feedbackDuplicateAddress(feedback: let feedback):
            return "The address {deviceID=\(feedback.deviceID), contactID=\(feedback.contactID)} of feedback \(feedback.name) is already used by another feedback"
        case .unusedFeedback(feedback: let feedback):
            return "Feedback \(feedback.name) is not used in the layout"
            
        case .blockIdAlreadyExists(block: let block):
            return "Block ID \(block.id) (named \(block.name)) is used by more than one block"
        case .blockNameAlreadyExists(block: let block):
            return "Block name \(block.name) is used by more than one block"
        case .blockDuplicateFeedback(block: let block, feedback: let feedback):
            return "Block \(block.name) uses feedback \(feedback.name) which is already used by another block"
            
        case .turnoutIdAlreadyExists(turnout: let turnout):
            return "Turnout ID \(turnout.id) (named \(turnout.name)) is used by more than one turnout"
        case .turnoutNameAlreadyExists(turnout: let turnout):
            return "Turnout name \(turnout.name) is used by more than one turnout"
        case .turnoutMissingTransition(turnout: let turnout, socket: let socket):
            return "Turnout \(turnout.name) is missing a transition from socket \(socket)"
        case .turnoutDuplicateAddress(turnout: let turnout):
            if turnout.doubleAddress {
                return "The address of turnout \(turnout.name) (\(turnout.address):\(turnout.address2)) is already used by another turnout"
            } else {
                return "The address of turnout \(turnout.name) (\(turnout.addressValue)) is already used by another turnout"
            }
        case .turnoutSameDoubleAddress(turnout: let turnout):
            return "The addresses of turnout \(turnout.name) (\(turnout.address):\(turnout.address2)) are the same"
            
        case .blockMissingTransition(block: let block, socket: let socket):
            return "Block \(block.name) is missing a transition from socket \(socket)"
        case .invalidTransition(transitionId: let transitionId, socket: let socket):
            return "Transition \(transitionId) is not connected via its socket \(socket)"
            
        case .blockMissingLength(block: let block):
            return "Block \(block.name) does not have a length defined"
        case .turnoutMissingLength(turnout: let turnout):
            return "Turnout \(turnout.name) does not have a length defined"
        case .blockFeedbackInvalidDistance(block: let block, feedback: let feedback):
            return "Feedback \(feedback.id) has an invalid distance of \(feedback.distance!) inside block \(block.name) of length \(block.length!)"
        case .blockFeedbackMissingDistance(block: let block, feedbackId: let feedbackId):
            return "Block \(block.name) does not have a distance defined for feedback \(feedbackId)"
            
        case .trainMissingLength(train: let train):
            return "Train \(train.name) does not have a length defined"
        case .invalidRoute(route: let route, error: let error):
            return "Route \"\(route.name)\" is invalid and cannot be resolved: \(error)"
            
        case .trainIdAlreadyExists(train: let train):
            return "Train ID \(train.id) (named \(train.name)) is used by more than one train"
        case .trainNameAlreadyExists(train: let train):
            return "Train \(train.name) is used by more than one train"
        case .trainLocomotiveUndefined(train: let train):
            return "Train \(train.name) does not have a locomotive assigned to it"

        case .locIdAlreadyExists(loc: let loc):
            return "Locomotive ID \(loc.id) (named \(loc.name)) is used by more than one locomotive"
        case .locNameAlreadyExists(loc: let loc):
            return "Locomotive \(loc.name) is used by more than one locomotive"
        case .locDuplicateAddress(loc: let loc):
            return "The address of locomotive \(loc.name) (\(loc.address.actualAddress(for: loc.decoder))) is already used by another locomotive"
        case .locMissingLength(loc: let loc):
            return "Locomotive \(loc.name) does not have a length defined"
        }
    }
}
