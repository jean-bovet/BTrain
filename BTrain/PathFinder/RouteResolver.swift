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

// A route consists of one or more steps. Each step defines a turnout or a block that the train needs to follow.
// The steps of a route do not necessarily contain contiguous turnout or block. For example, the user can create a route
// with just a few blocks specified and it will be up to this class to find out the missing turnouts (and blocks) to
// create a contiguous route.
// At the moment, only missing turnouts will be handled but in a future release, missing blocks will be supported as well.
final class RouteResolver {
    
    let layout: Layout
    let pf: PathFinder
    
    lazy var settings: PathFinderSettings = {
        var settings = PathFinderSettings(random: false, reservedBlockBehavior: .avoidReservedUntil(numberOfSteps: 0), consideringStoppingAtSiding: false, verbose: true)
        settings.includeTurnouts = true
        settings.ignoreDisabledBlocks = true
        settings.firstBlockShouldMatchDestination = true
        return settings
    }()
    
    init(layout: Layout) {
        self.layout = layout
        self.pf = PathFinder(layout: layout)
    }
    
    // TODO: at the moment, we assume the steps provided contain only contiguous block. This will have to change in the future
    // to include possible turnouts and non-contiguous blocks.
    func resolve(steps: ArraySlice<Route.Step>, trainId: Identifier<Train>? = nil) throws -> [Route.Step] {
        guard var previousStep = steps.first else {
            return []
        }
        var resolvedSteps = [previousStep]
        for step in steps.dropFirst() {
            guard let previousBlock = layout.block(for: previousStep.blockId) else {
                continue
            }
            
            guard let previousDirection = previousStep.direction else {
                // TODO: throw
                fatalError()
            }
            
            guard let block = layout.block(for: step.blockId) else {
                continue
            }

            guard let direction = step.direction else {
                // TODO: throw
                fatalError()
            }

            // Find the missing turnouts between `previousBlock` and `block`
            let destination = Destination(block.id, direction: direction)
            if let path = try pf.path(trainId: trainId, from: previousBlock, destination: destination, direction: previousDirection, settings: settings) {
                // Insert the turnouts that have been discovered
                for turnoutStep in path.steps.filter({ $0.turnoutId != nil }) {
                    resolvedSteps.append(turnoutStep)
                }
            }
            resolvedSteps.append(step)
            previousStep = step
        }
        return resolvedSteps
    }
}
