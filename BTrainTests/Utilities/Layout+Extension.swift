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

@testable import BTrain

extension Layout {
    
    func turnouts(from fromBlock: Block, to nextBlock: Block, direction: Direction) throws -> [Turnout] {
        let transitions = try transitions(from: fromBlock, to: nextBlock, direction: direction)
        var turnouts = [Turnout]()
        for transition in transitions {
            if let turnoutId = transition.b.turnout {
                guard let turnout = turnout(for: turnoutId) else {
                    fatalError("Unable to find turnout \(turnoutId)")
                }
                turnouts.append(turnout)
            }
        }
        return turnouts
    }

    func newRoute(id: String, _ steps: [(String, Direction)]) -> Route {
        return newRoute(id, name: id, steps.map({ step in
            return Route.Step(Identifier<Block>(uuid: step.0), step.1)
        }))
    }
    
    func prepare(routeID: String, trainID: String) throws {
        try prepare(routeID: Identifier<Route>(uuid: routeID),
                    trainID: Identifier<Train>(uuid: trainID))
    }

    func prepare(routeID: Identifier<Route>, trainID: Identifier<Train>, toBlockId: Identifier<Block>? = nil, startAtEndOfBlock: Bool = false) throws {
        guard let route = route(for: routeID, trainId: trainID) else {
            throw LayoutError.routeNotFound(routeId: routeID)
        }

        guard let train = train(for: trainID) else {
            throw LayoutError.trainNotFound(trainId: trainID)
        }

        guard let firstStep = route.steps.first else {
            throw LayoutError.noSteps(routeId: routeID)
        }

        if let block = block(for: firstStep.blockId) {
            try setTrainToBlock(train.id, block.id, position: startAtEndOfBlock ? .end : .start, direction: .next)

            train.routeId = route.id
            train.routeStepIndex = 0
            train.speed.kph = 0
        }
    }

}
