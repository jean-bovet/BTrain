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
    var shouldStopInBlock: Bool {
        shouldStopInBlock(ignoreReservedBlocks: false)
    }
    
    /// Returns true if the train should stop in the current block
    /// - Parameter ignoreReservedBlocks: true to ignore the reserved blocks. For example, to allow a train to start,
    /// we need to ignore the reserved block because the train, which is stopped, doesn't have any reserved blocks yet.
    /// - Returns: true if the train should stop in the current block
    func shouldStopInBlock(ignoreReservedBlocks: Bool) -> Bool {
        guard mode != .unmanaged else {
            return false
        }
        
        // User requested to stop managing the train?
        if mode == .stopManaged {
            return true
        }
        
        // User requested to finish managing the train when it reaches the end of the route?
        if mode == .finishManaged && currentRouteIndex >= endRouteIndex {
            return true
        }

        // In a station but not in the first step of the route?
        if atStationOrDestination && currentRouteIndex > startedRouteIndex {
            return true
        }
        
        // At the end of the route?
        if currentRouteIndex >= endRouteIndex && route.mode != .automatic {
            return true
        }
        
        if !ignoreReservedBlocks {
            // Not enough room to run at least at limited speed?
            if !reservedBlocksLengthEnough(forSpeed: LayoutFactory.DefaultBrakingSpeed) {
                return true
            }
        }

        return false
    }

}
