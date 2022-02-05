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

// This class is used to keep track of the various parameters during analysis
final class PathFinderContext {
    // Train associated with this path
    let train: Train?

    // The destination or nil if any station block can be chosen
    let destination: Destination?
    
    // The maximum number of blocks in the path before
    // it overflows and the algorithm ends the analysis.
    // This is to avoid situation in which the algorithm
    // takes too long to return.
    let overflow: Int

    // Settings for the algorithm
    let settings: PathFinderSettings

    // The list of steps defining this path
    var steps = [Route.Step]()

    // The list of visited steps (block+direction),
    // used to ensure the algorithm does not
    // re-use a block and ends up in an infinite loop.
    var visitedSteps = [Route.Step]()
    
    init(train: Train?, destination: Destination?, overflow: Int, settings: PathFinderSettings) {
        self.train = train
        self.destination = destination
        self.overflow = overflow
        self.settings = settings
    }
    
    func hasVisited(_ step: Route.Step) -> Bool {
        return visitedSteps.contains { $0.same(step) }
    }

    var isOverflowing: Bool {
        return steps.count >= overflow
    }
    
    func print(_ msg: String) {
        if settings.verbose {
            BTLogger.debug(" \(msg)")
        }
    }
}
