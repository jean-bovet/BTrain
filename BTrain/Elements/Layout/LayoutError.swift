// Copyright 2021 Jean Bovet
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
    case trainNotAssignedToABlock(trainId: Identifier<Train>)
    case trainNotFoundInBlock(blockId: Identifier<Block>)
    case trainInBlockDoesNotMatch(trainId: Identifier<Train>, blockId: Identifier<Block>, blockTrainId: Identifier<Train>)
    case trainNotFoundInRoute(train: ITrain, route: Route)
    case trainNotAssignedToARoute(train: ITrain)

    case blockNotFound(blockId: Identifier<Block>)
    case turnoutNotFound(turnoutId: Identifier<Turnout>)
    case feedbackNotFound(feedbackId: Identifier<Feedback>)
    case socketIdNotFound(socket: Socket)
    
    case blockNotEmpty(blockId: Identifier<Block>)
    case blockNotReservedForTrain(block: Block, train: Identifier<Train>)
    
    case noTransition(fromBlockId: Identifier<Block>, toBlockId: Identifier<Block>)
    case lastTransitionToBlock(transition: Identifier<Transition>, blockId: Identifier<Block>)
    case alwaysOneAndOnlyOneTransition
    
    case cannotReserveTransition(transition: Identifier<Transition>, trainId: Identifier<Train>, reserved: Identifier<Train>)
    case cannotReserveTurnout(turnout: Identifier<Turnout>, trainId: Identifier<Train>, reserved: Identifier<Train>)
    case cannotReserveBlock(blockId: Identifier<Block>, trainId: Identifier<Train>, reserved: Reservation)
    
    case routeNotFound(routeId: Identifier<Route>)
    case noSteps(routeId: Identifier<Route>)
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
        case .noTransition(fromBlockId: let fromBlockId, toBlockId: let toBlockId):
            return "No transition found from block \(fromBlockId) to block \(toBlockId)"
        case .lastTransitionToBlock(transition: let transition, blockId: let blockId):
            return "The last transition \(transition) should be to block \(blockId)"
        case .cannotReserveTransition(transition: let transition, trainId: let trainId, reserved: let reserved):
            return "Cannot reserve transition \(transition) for train \(trainId) because the transition is already reserved for \(reserved)"
        case .cannotReserveTurnout(turnout: let turnout, trainId: let trainId, reserved: let reserved):
            return "Cannot reserve turnout \(turnout) for train \(trainId) because the turnout is already reserved for \(reserved)"
        case .cannotReserveBlock(blockId: let blockId, trainId: let trainId, reserved: let reserved):
            return "Cannot reserve block \(blockId) for train \(trainId) because the block is already reserved for \(reserved)"
        case .socketIdNotFound(socket: let socket):
            return "There is no socket defined for \(socket)"
        case .trainNotAssignedToABlock(trainId: let trainId):
            return "Train \(trainId) does not have any assigned block (train.blockId is nil)"
        case .trainNotFoundInBlock(blockId: let blockId):
            return "Block \(blockId) does not have any train assigned to it (TrainInstance is nil)"
        case .trainInBlockDoesNotMatch(trainId: let trainId, blockId: let blockId, blockTrainId: let blockTrainId):
            return "Block \(blockId) has another train (\(blockTrainId)) than \(trainId) assigned to it"
        case .trainNotFoundInRoute(train: let train, route: let route):
            return "Train \(train.name) not found in route \(route.name)"
        case .trainNotAssignedToARoute(train: let train):
            return "Train \(train.name) has no associated route"
        case .routeNotFound(routeId: let routeId):
            return "Route \(routeId) not found"
        case .noSteps(routeId: let routeId):
            return "No steps defined in route \(routeId)"
        case .alwaysOneAndOnlyOneTransition:
            return "There must always be only one and only one transition"
        }
    }
}
