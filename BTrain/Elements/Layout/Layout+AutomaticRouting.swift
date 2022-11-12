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

extension Layout {
    
    enum UpdateRouteError: Error {
        case cannotUpdateRoute(message: String)
    }
    
    /// Update the automatic route associated with the train
    /// - Parameter trainId: The train
    /// - Returns: the result of updating the automatic route
    func updateAutomaticRoute(for trainId: Identifier<Train>) throws -> Result<Route, UpdateRouteError> {
        let routeId = Route.automaticRouteId(for: trainId)
        
        guard let route = route(for: routeId, trainId: trainId) else {
            throw LayoutError.routeNotFound(routeId: routeId)
        }
        
        guard let train = train(for: trainId) else {
            throw LayoutError.trainNotFound(trainId: trainId)
        }
                        
        // Determine the destination of the route
        let destination: Destination?
        switch route.mode {
        case .automaticOnce(destination: let routeDestination):
            destination = routeDestination
        case .automatic:
            destination = nil
        case .fixed:
            throw LayoutError.routeIsNotAutomatic(route: route)
        }
        
        // Determine the destination block, if available
        let to: LayoutVector?
        if let destination = destination {
            guard let block = block(for: destination.blockId) else {
                throw LayoutError.blockNotFound(blockId: destination.blockId)
            }
            to = .init(block: block, direction: destination.direction)
        } else {
            to = nil
        }
        
        // Find the best path by avoiding reserved blocks
        let path = try bestPath(ofTrain: train, toReachBlock: to?.block, withDirection: to?.direction,
                                reservedBlockBehavior: .avoidReserved)
        
        if let path = path {
            route.lastMessage = nil
            route.steps = path.elements.toBlockSteps
            train.routeStepIndex = 0
            train.startRouteIndex = 0
            return .success(route)
        } else {
            let message: String
            if let to = to {
                message = "No route available to \(to.block.name)"
            } else {
                message = "No route available"
            }
            route.lastMessage = message
            route.steps.removeAll()
            train.routeStepIndex = 0
            train.startRouteIndex = 0
            return .failure(.cannotUpdateRoute(message: message))
        }
    }

}
