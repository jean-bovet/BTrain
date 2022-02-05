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

struct PathFinderSettings {
    // True to generate a route at random, false otherwise.
    let random: Bool
        
    enum ReservedBlockBehavior {
        // Avoid all the reserved blocks
        case avoidReserved
        
        // Avoid the reserved blocks for the first
        // `numberOfSteps` of the route. After the route
        // has more steps than this, reserved block
        // will be taken into consideration. This option is
        // used in automatic routing when no particular destination
        // block is specified: BTrain will update the route if a
        // reserved block is found during the routing of the train.
        case avoidReservedUntil(numberOfSteps: Int)
    }
    
    let reservedBlockBehavior: ReservedBlockBehavior
            
    var consideringStoppingAtSiding = false
    
    var includeTurnouts = false
    
    var ignoreDisabledBlocks = false
    
    // True if the first block that is found must match the destination.
    // TODO: add support for looking up block that are further than 1 block in distance.
    // This will be needed when a route is specified only with sparse block that are more than
    // one block appart. In that case, the algorithm should be changed to a traversal first algorithm
    // where we try out depth 1 first, then depth 2 second, etc, in order to find the block with the shortest path first.
    var firstBlockShouldMatchDestination = false
    
    let verbose: Bool
}
