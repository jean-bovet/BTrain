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

extension TrainController: TrainControlling {
    
    func scheduleRestartTimer(train: Train) {
        delegate?.scheduleRestartTimer(train: train)
    }
    
    func stop(completely: Bool) throws -> TrainHandlerResult {
        train.stopTrigger = nil
                                
        BTLogger.debug("Stop train \(train)")
        
        try layout.stopTrain(train.id, completely: completely) { }
                
        return .none()
    }
            
    func reserveLeadBlocks(route: Route, currentBlock: Block, trainStarting: Bool) throws -> Bool {
        if try layout.reservation.updateReservedBlocks(train: train, trainStarting: trainStarting) {
            return true
        }
        
        guard route.automatic else {
            return false
        }
        
        BTLogger.debug("Generating a new route for \(train) at block \(currentBlock.name) because the next blocks could not be reserved (route: \(route.steps.debugDescription))")

        // Update the automatic route
        if try updateAutomaticRoute(for: train.id) {
            // And try to reserve the lead blocks again
            return try layout.reservation.updateReservedBlocks(train: train, trainStarting: trainStarting)
        } else {
            return false
        }
    }

    private func updateAutomaticRoute(for trainId: Identifier<Train>) throws -> Bool {
        let (success, route) = try layout.automaticRouting.updateAutomaticRoute(for: train.id)
        if success {
            BTLogger.debug("Generated route is: \(route.steps)")
            return true
        } else {
            BTLogger.warning("Unable to find a suitable route for train \(train)")
            return false
        }
    }
    
}
