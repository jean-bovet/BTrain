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

struct RouteStep_v1: Codable {
    let id: String

    var blockId: Identifier<Block>?

    var direction: Direction?

    var turnoutId: Identifier<Turnout>?

    // The number of seconds a train will wait in that block
    // If nil, the block waitingTime is used instead.
    var waitingTime: TimeInterval?

    // Returns the socket where the train will exit
    // the block represented by this step, taking
    // into account the direction of travel of the train.
    var exitSocket: Socket?

    // Returns the socket where the train will enter
    // the block represented by this step, taking
    // into account the direction of travel of the train.
    var entrySocket: Socket?
}

extension Array where Element == RouteStep_v1 {
    var toRouteSteps: [RouteItem] {
        map { routeStepv1 in
            routeStepv1.toRouteStep
        }
    }
}

extension RouteStep_v1 {
    var toRouteStep: RouteItem {
        if let blockId = blockId {
            if let direction = direction {
                return .block(RouteItemBlock(blockId, direction, waitingTime))
            } else {
                if entrySocket?.socketId == Block.previousSocket {
                    return .block(RouteItemBlock(blockId, .next, waitingTime))
                } else {
                    return .block(RouteItemBlock(blockId, .previous, waitingTime))
                }
            }
        } else if let turnoutId = turnoutId {
            return .turnout(RouteItemTurnout(turnoutId, entrySocket!, exitSocket!))
        } else {
            fatalError("Unknown step configuration: \(self)")
        }
    }
}
