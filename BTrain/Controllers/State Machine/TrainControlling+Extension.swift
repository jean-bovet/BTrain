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

extension TrainControlling {
    /// Returns true if the train should stop in the current block
    func shouldStopInBlock() throws -> Bool {
        try shouldStopInBlock(ignoreReservedBlocks: false, ignoreChangeInDirection: false)
    }

    /// Returns true if the train should stop in the current block because there is not enough
    /// reserved (and settled) blocks for it.
    func shouldStopInBlockBecauseNotEnoughReservedBlocksLength() throws -> Bool {
        try !reservedBlocksLengthEnough(forSpeed: LayoutFactory.DefaultBrakingSpeed)
    }

    /// Returns true if the train should stop in the current block
    /// - Parameters:
    ///   - ignoreReservedBlocks: true to ignore the reserved blocks.
    ///   - ignoreChangeInDirection: true to ignore change in direction request.
    /// - Returns: true if the train should stop in the current block
    ///
    ///
    func shouldStopInBlock(ignoreReservedBlocks: Bool, ignoreChangeInDirection: Bool) throws -> Bool {
        guard mode != .unmanaged else {
            return false
        }

        // User requested to stop managing the train?
        if mode == .stopManaged || mode == .stopImmediatelyManaged {
            return true
        }

        // User requested to finish managing the train when it reaches the end of the route?
        if mode == .finishManaged, currentRouteIndex >= endRouteIndex {
            return true
        }

        // In a station but not in the first step of the route?
        if atStationOrDestination, currentRouteIndex > startedRouteIndex {
            return true
        }

        // At the end of the route?
        if currentRouteIndex >= endRouteIndex, route.mode != .automatic {
            return true
        }

        // If there is not enough reserved block length available, we should stop
        if !ignoreReservedBlocks {
            if try shouldStopInBlockBecauseNotEnoughReservedBlocksLength() {
                return true
            }
        }

        // If the block requires a change of direction, we need to stop
        if !ignoreChangeInDirection, shouldChangeDirection {
            return true
        }

        return false
    }
}
