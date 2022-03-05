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
    
    lazy var settings: PathFinder.Settings = {
        var settings = PathFinder.Settings(random: false,
                                           reservedBlockBehavior: .ignoreReserved,
                                           consideringStoppingAtSiding: false,
                                           verbose: SettingsKeys.bool(forKey: SettingsKeys.logRoutingResolutionSteps))
        settings.includeTurnouts = true
        settings.ignoreDisabledElements = true
        settings.firstBlockShouldMatchDestination = true
        return settings
    }()
    
    init(layout: Layout) {
        self.layout = layout
        self.pf = PathFinder(layout: layout)
    }
    
    // This function takes an array of steps and returns a resolved array of steps. The returned array
    // contains all the blocks and turnouts that were not explicitely indicated in the first array.
    // Note: a train must be specified in order to resolve the steps because a train can have specific requirements
    // to avoid certain blocks or turnouts, in addition to the algorithm checking allowing block (or turnout)
    // already reserved for the same train to be accepted as resolved steps.
    // Returns nil if the route cannot be resolved. This can happen, for example, if a turnout or block is already
    // reserved for another train and no other alternative path is found.
    func resolve(steps: ArraySlice<Route.Step>, trainId: Identifier<Train>) throws -> [Route.Step]? {
        guard var previousStep = steps.first else {
            return []
        }
        var resolvedSteps = [previousStep]
        for step in steps.dropFirst() {
            guard let previousBlock = layout.block(for: previousStep.blockId) else {
                continue
            }
            
            guard let previousDirection = previousStep.direction else {
                throw LayoutError.missingDirection(step: previousStep)
            }
            
            guard let block = layout.block(for: step.blockId) else {
                continue
            }

            guard let direction = step.direction else {
                throw LayoutError.missingDirection(step: step)
            }

            // Find the missing turnouts between `previousBlock` and `block`
            let destination = Destination(block.id, direction: direction)
            if let path = try pf.path(trainId: trainId, from: previousBlock, destination: destination, direction: previousDirection, settings: settings) {
                // Insert the turnouts that have been discovered
                for turnoutStep in path.steps.filter({ $0.turnoutId != nil }) {
                    resolvedSteps.append(turnoutStep)
                }
            } else {
                // Bail out if a path cannot be found between two blocks.
                return nil
            }
            resolvedSteps.append(step)
            previousStep = step
        }
        return resolvedSteps
    }
}
