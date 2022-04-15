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

enum LayoutError: Error {
    case trainNotFound(trainId: Identifier<Train>)
    case trainNotAssignedToABlock(train: Train)
    case trainNotFoundInBlock(blockId: Identifier<Block>)
    case trainInBlockDoesNotMatch(trainId: Identifier<Train>, blockId: Identifier<Block>, blockTrainId: Identifier<Train>)
    case trainNotFoundInRoute(train: Train, route: Route)
    case trainNotAssignedToARoute(train: Train)
    
    case headWagonNotFound(train: Train)
    case invalidHeadWagonConfiguration(train: Train)
    
    case blockNotFound(blockId: Identifier<Block>)
    case turnoutNotFound(turnoutId: Identifier<Turnout>)
    case feedbackNotFound(feedbackId: Identifier<Feedback>)
    case socketIdNotFound(socket: Socket)
        
    case entrySocketNotFound(step: Route.Step)
    case exitSocketNotFound(step: Route.Step)
    case invalidSocket(socket: Socket)

    case brakeFeedbackNotFound(block: Block)
    case stopFeedbackNotFound(block: Block)

    case blockNotEmpty(blockId: Identifier<Block>)
    case blockNotReservedForTrain(block: Block, train: Identifier<Train>)

    case blockAlreadyReserved(block: Block)
    case turnoutAlreadyReserved(turnout: Turnout)
    case transitionAlreadyReserved(transition: ITransition)
    
    case unexpectedFeedback(feedback: Feedback)
    
    case noTransition(fromBlockId: Identifier<Block>, toBlockId: Identifier<Block>)
    case lastTransitionToBlock(transition: Identifier<Transition>, blockId: Identifier<Block>)
    case alwaysOneAndOnlyOneTransition
    case invalidTransition(transition: ITransition)
    
    case cannotReserveBlock(block: Block, train: Train, reserved: Reservation)
    
    case routeNotFound(routeId: Identifier<Route>)
    case noPossibleRoute(train: Train)
    
    case noSteps(routeId: Identifier<Route>)
    
    case destinationBlockMismatch(currentBlock: Block, destination: Destination)
    case destinationDirectionMismatch(currentBlock: Block, destination: Destination)
    
    case missingDirection(step: Route.Step)
    case invalidDirectionRequest(step: Route.Step)
    case invalidDirectionAssignment(step: Route.Step)
    case invalidState(step: Route.Step)
    
    case invalidPartIndex(index: Int, block: Block)
    
    case shapeNotFoundForSocket(socket: Socket)
}
    
extension LayoutError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .trainNotFound(trainId: let trainId):
            return "Train \(trainId) not found"
        case .blockNotFound(blockId: let blockId):
            return "Block \(blockId) not found"
        case .turnoutNotFound(turnoutId: let turnoutId):
            return "Turnout \(turnoutId) not found"
        case .feedbackNotFound(feedbackId: let feedbackId):
            return "Feedback \(feedbackId) not found"
        case .blockNotEmpty(blockId: let blockId):
            return "Block \(blockId) is not empty"
        case .blockNotReservedForTrain(block: let block, train: let train):
            return "Block \(block.name) did not get reserved for train \(train)"
            
        case .brakeFeedbackNotFound(block: let block):
            return "Block \(block.name) does not have a brake feedback"

        case .stopFeedbackNotFound(block: let block):
            return "Block \(block.name) does not have a stop feedback"

        case .unexpectedFeedback(feedback: let feedback):
            return "Unexpected feedback \(feedback.name) detected"

        case .noTransition(fromBlockId: let fromBlockId, toBlockId: let toBlockId):
            return "No transition found from block \(fromBlockId) to block \(toBlockId)"
        case .lastTransitionToBlock(transition: let transition, blockId: let blockId):
            return "The last transition \(transition) should be to block \(blockId)"
        case .cannotReserveBlock(block: let block, train: let train, reserved: let reserved):
            return "Cannot reserve block \(block.name) for train \(train.name) because the block is already reserved for \(reserved)"
            
        case .socketIdNotFound(socket: let socket):
            return "There is no socket defined for \(socket)"
        case .entrySocketNotFound(step: let step):
            return "There is no entry socket defined for \(step)"
        case .exitSocketNotFound(step: let step):
            return "There is no exit socket defined for \(step)"
        case .invalidSocket(socket: let socket):
            return "Socket \(socket) must have either its block or turnout defined"

        case .trainNotAssignedToABlock(train: let train):
            return "Train \(train.name) does not have any assigned block (train.blockId is nil)"
        case .trainNotFoundInBlock(blockId: let blockId):
            return "Block \(blockId) does not have any train assigned to it (TrainInstance is nil)"
        case .trainInBlockDoesNotMatch(trainId: let trainId, blockId: let blockId, blockTrainId: let blockTrainId):
            return "Block \(blockId) has another train (\(blockTrainId)) than \(trainId) assigned to it"
        case .trainNotFoundInRoute(train: let train, route: let route):
            return "Train \(train.name) not found in route \(route.name)"
        case .trainNotAssignedToARoute(train: let train):
            return "Train \(train.name) has no associated route"
            
        case .headWagonNotFound(train: let train):
            return "No head wagon found for train \(train.name)"
        case .invalidHeadWagonConfiguration(train: let train):
            return "It is an error to ask for the head wagon when the locomotive is not pushing its wagons: \(train)"

        case .routeNotFound(routeId: let routeId):
            return "Route \(routeId) not found"
        case .noPossibleRoute(train: let train):
            return "No automatic route found for \(train.name)"

        case .noSteps(routeId: let routeId):
            return "No steps defined in route \(routeId)"
        case .alwaysOneAndOnlyOneTransition:
            return "There must always be only one and only one transition"
            
        case .destinationBlockMismatch(currentBlock: let currentBlock, destination: let destination):
            return "The destination block \(destination.blockId) does not match the current block \(currentBlock.id) (\(currentBlock.name))"
        case .destinationDirectionMismatch(currentBlock: let currentBlock, destination: let destination):
            return "The destination direction \(String(describing: destination.direction)) does not match the current direction of the train within the block \(String(describing: currentBlock.train?.direction)), at block \(currentBlock.name) (\(currentBlock.id))"
            
        case .blockAlreadyReserved(block: let block):
            return "Block \(block.name) is already reserved for \(String(describing: block.reserved))"
        case .turnoutAlreadyReserved(turnout: let turnout):
            return "Turnout \(turnout.name) is already reserved for \(String(describing: turnout.reserved))"
        case .transitionAlreadyReserved(transition: let transition):
            return "Transition \(transition.id) is already reserved for \(String(describing: transition.reserved))"
            
        case .missingDirection(step: let step):
            return "Direction is missing from \(step)"
        case .invalidState(step: let step):
            return "Invalid step \(step)"

        case .invalidPartIndex(index: let index, block: let block):
            return "Invalid part index \(index) in \(block.name)"
        case .invalidDirectionRequest(step: let step):
            return "It is an error to request the direction for a step that does not refer to a block: \(step)"
        case .invalidDirectionAssignment(step: let step):
            return "It is an error to set the direction of a step that does not refer to a block: \(step)"
        case .invalidTransition(transition: let transition):
            return "Invalid transition \(transition)"
        case .shapeNotFoundForSocket(socket: let socket):
            return "Unable to find a shape for socket \(socket)"
        }
    }
}
