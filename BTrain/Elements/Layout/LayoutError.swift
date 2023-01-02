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
    case trainNotFoundInRoute(train: Train, route: Route)
    case trainNotAssignedToARoute(train: Train)
    case trainLengthNotDefined(train: Train)

    case locomotiveNotAssignedToTrain(train: Train)

    case headWagonNotFound(train: Train)
    case invalidHeadWagonConfiguration(train: Train)

    case blockNotFound(blockId: Identifier<Block>)
    case blockNotFoundInStation(stationId: Identifier<Station>)
    case stationNotFound(stationId: Identifier<Station>)
    case turnoutNotFound(turnoutId: Identifier<Turnout>)
    case directionNotFound(blockId: Identifier<Block>)

    case socketIdNotFound(socket: Socket)
    case invalidSocket(socket: Socket)

    case feedbackNotFound(feedbackId: Identifier<Feedback>)
    case feedbackNotFoundInBlock(feedbackId: Identifier<Feedback>, block: Block)
    case blockContainsNoFeedback(block: Block)
    case feedbackDistanceNotSet(feedback: Block.BlockFeedback)

    case frontPositionNotSpecified(position: TrainPositions)
    case backPositionNotSpecified(position: TrainPositions)
    case noPositionsSpecified(position: TrainPositions)

    case frontPositionBlockNotSpecified(position: TrainPositions)
    case backPositionBlockNotSpecified(position: TrainPositions)

    case brakeFeedbackNotFound(block: Block)
    case stopFeedbackNotFound(block: Block)

    case blockNotEmpty(blockId: Identifier<Block>)
    case blockNotReservedForTrain(block: Block, train: Identifier<Train>)
    case blockLengthNotDefined(block: Block)

    case blockAlreadyReserved(block: Block)
    case turnoutAlreadyReserved(turnout: Turnout)
    case transitionAlreadyReserved(train: Train, transition: Transition)

    case unexpectedFeedback(feedback: Feedback)

    case noTransition(fromBlock: Block, toBlock: Block)
    case lastTransitionToBlock(transition: Identifier<Transition>, blockId: Identifier<Block>)
    case alwaysOneAndOnlyOneTransition
    case invalidTransition(transition: Transition)

    case cannotReserveBlock(block: Block, train: Train, reserved: Reservation)
    case cannotReserveAllElements(train: Train)
    case cannotChangeRouteWhileTrainIsRunning(train: Train, route: Route)

    case routeNotFound(routeId: Identifier<Route>)
    case noPossibleRoute(train: Train)
    case routeIsNotAutomatic(route: Route)

    case destinationBlockMismatch(currentBlock: Block, destination: Destination)

    case invalidPartIndex(index: Int, block: Block)

    case shapeNotFoundForSocket(socket: Socket)
}

extension LayoutError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .trainNotFound(trainId: trainId):
            return "Train \(trainId) not found"
        case let .blockNotFound(blockId: blockId):
            return "Block \(blockId) not found"
        case let .blockNotFoundInStation(stationId: stationId):
            return "No block found in station \(stationId)"
        case let .stationNotFound(stationId: stationId):
            return "Station \(stationId) not found"
        case let .turnoutNotFound(turnoutId: turnoutId):
            return "Turnout \(turnoutId) not found"
        case let .blockNotEmpty(blockId: blockId):
            return "Block \(blockId) is not empty"
        case let .blockNotReservedForTrain(block: block, train: train):
            return "Block \(block.name) did not get reserved for train \(train)"

        case let .feedbackNotFound(feedbackId: feedbackId):
            return "Feedback \(feedbackId) not found"
        case let .feedbackNotFoundInBlock(feedbackId: feedbackId, block: block):
            return "Feedback \(feedbackId) not found in block \(block.name)"
        case let .blockContainsNoFeedback(block: block):
            return "Block \(block.name) contains no feedback"
        case let .blockLengthNotDefined(block: block):
            return "Block \(block.name) does not have its length defined"

        case let .feedbackDistanceNotSet(feedback: feedback):
            return "Feedback \(feedback.feedbackId) distance not set"

        case let .brakeFeedbackNotFound(block: block):
            return "Block \(block.name) does not have a brake feedback"

        case let .stopFeedbackNotFound(block: block):
            return "Block \(block.name) does not have a stop feedback"

        case let .unexpectedFeedback(feedback: feedback):
            return "Unexpected feedback \(feedback.name) detected"

        case let .noTransition(fromBlock: fromBlock, toBlock: toBlock):
            return "No transition found from block \(fromBlock) to block \(toBlock)"
        case let .lastTransitionToBlock(transition: transition, blockId: blockId):
            return "The last transition \(transition) should be to block \(blockId)"
        case let .cannotReserveBlock(block: block, train: train, reserved: reserved):
            return "Cannot reserve block \(block.name) for train \(train.name) because the block is already reserved for \(reserved)"
        case let .cannotReserveAllElements(train: train):
            return "Cannot reserve all the elements that train \(train.name) occupies"
        case let .cannotChangeRouteWhileTrainIsRunning(train: train, route: route):
            return "Cannot change route \(route.name) when train \(train.name) is running"

        case let .socketIdNotFound(socket: socket):
            return "There is no socket defined for \(socket)"
        case let .directionNotFound(blockId: blockId):
            return "Direction not found in occupied block \(blockId)"

        case let .invalidSocket(socket: socket):
            return "Socket \(socket) must have either its block or turnout defined"

        case let .frontPositionBlockNotSpecified(position: position):
            return "Head position block not specified: \(position)"
        case let .backPositionBlockNotSpecified(position: position):
            return "Tail position block not specified: \(position)"

        case let .frontPositionNotSpecified(position: position):
            return "Head position not specified: \(position)"
        case let .backPositionNotSpecified(position: position):
            return "Tail position not specified: \(position)"
        case .noPositionsSpecified(position: let position):
            return "Head and tail positions not specified: \(position)"

        case let .trainNotAssignedToABlock(train: train):
            return "Train \(train.name) does not have any assigned block (train.block is nil)"
        case let .trainNotFoundInBlock(blockId: blockId):
            return "Block \(blockId) does not have any train assigned to it (TrainInstance is nil)"
        case let .trainNotFoundInRoute(train: train, route: route):
            return "Train \(train.name) not found in route \(route.name)"
        case let .trainNotAssignedToARoute(train: train):
            return "Train \(train.name) has no associated route"
        case .trainLengthNotDefined(train: let train):
            return "Train \(train.name) has no length defined"

        case let .headWagonNotFound(train: train):
            return "No head wagon found for train \(train.name)"
        case let .invalidHeadWagonConfiguration(train: train):
            return "It is an error to ask for the head wagon when the locomotive is not pushing its wagons: \(train)"

        case let .routeNotFound(routeId: routeId):
            return "Route \(routeId) not found"
        case let .noPossibleRoute(train: train):
            return "No automatic route found for \(train.name)"
        case let .routeIsNotAutomatic(route: route):
            return "The route \(route.name) is not automatic"

        case .alwaysOneAndOnlyOneTransition:
            return "There must always be only one and only one transition"

        case let .destinationBlockMismatch(currentBlock: currentBlock, destination: destination):
            return "The destination block \(destination.blockId) does not match the current block \(currentBlock.id) (\(currentBlock.name))"

        case let .blockAlreadyReserved(block: block):
            return "Block \(block.name) is already reserved for \(String(describing: block.reservation))"
        case let .turnoutAlreadyReserved(turnout: turnout):
            return "Turnout \(turnout.name) is already reserved for \(String(describing: turnout.reserved))"
        case let .transitionAlreadyReserved(train, transition):
            return "Train \(train.name): transition \(transition.id) is already reserved for \(transition.reserved!)"

        case let .invalidPartIndex(index: index, block: block):
            return "Invalid part index \(index) in \(block.name)"
        case let .invalidTransition(transition: transition):
            return "Invalid transition \(transition)"
        case let .shapeNotFoundForSocket(socket: socket):
            return "Unable to find a shape for socket \(socket)"

        case let .locomotiveNotAssignedToTrain(train: train):
            return "Train \(train.name) does not have a locomotive assigned to it"
        }
    }
}
