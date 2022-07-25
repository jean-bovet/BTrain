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

final class AutomaticRouting {
    
    let layout: Layout
    
    init(layout: Layout) {
        self.layout = layout
    }
    
    func updateAutomaticRoute(for trainId: Identifier<Train>) throws -> (Bool, Route) {
        let routeId = Route.automaticRouteId(for: trainId)
        
        guard let route = layout.route(for: routeId, trainId: trainId) else {
            throw LayoutError.routeNotFound(routeId: routeId)
        }
        
        guard let train = layout.train(for: trainId) else {
            throw LayoutError.trainNotFound(trainId: trainId)
        }
        
        guard let blockId = train.blockId else {
            throw LayoutError.trainNotAssignedToABlock(train: train)
        }
        
        guard let currentBlock = layout.block(for: blockId) else {
            throw LayoutError.blockNotFound(blockId: blockId)
        }
        
        let destination: Destination?
        switch(route.mode) {
        case .automaticOnce(destination: let routeDestination):
            destination = routeDestination
        case .automatic:
            destination = nil
        case .fixed:
            throw LayoutError.routeIsNotAutomatic(route: route)
        }
        
        guard let trainInstance = currentBlock.trainInstance else {
            throw LayoutError.trainNotFoundInBlock(blockId: currentBlock.id)
        }

        // Note: if `destination` is specified, always avoid reserved block. Otherwise,
        // just avoid the reserved block in front of the current one but ignore the others
        // (the automatic route will re-evaluate itself if it encounters a reserved block later
        // during execution, to avoid deadlocking).
        let settings = PathFinder.Settings(verbose: SettingsKeys.bool(forKey: SettingsKeys.logRoutingResolutionSteps),
                                                random: layout.automaticRouteRandom,
                                                overflow: layout.pathFinderOverflowLimit)
        let constraints = PathFinder.Constraints(layout: layout, train: train, reservedBlockBehavior: destination == nil ? .avoidFirstReservedBlock : .avoidReserved, relaxed: false)
        let pf = PathFinder(constraints: constraints, settings: settings)
        
        let to: (Block, Direction?)?
        if let destination = destination {
            guard let block = layout.block(for: destination.blockId) else {
                throw LayoutError.blockNotFound(blockId: destination.blockId)
            }
            to = (block, destination.direction)
        } else {
            to = nil
        }
        
        let path: GraphPath?
        if let to = to, let toBlockDirection = to.1, SettingsKeys.bool(forKey: SettingsKeys.shortestRouteEnabled) {
            path = try layout.shortestPath(for: train, from: (currentBlock, trainInstance.direction), to: (to.0, toBlockDirection), pathFinder: pf)
        } else {
            path = layout.path(for: train, from: (currentBlock, trainInstance.direction), to: to, pathFinder: pf)
        }
        
        if let path = path {
            route.lastMessage = nil
            route.steps = path.elements.toBlockSteps
            train.routeStepIndex = 0
            train.startRouteIndex = 0
            return (true, route)
        } else {
            if let to = to {
                route.lastMessage = "Unable to find a suitable route to \(to.0.name)"
            } else {
                route.lastMessage = "Unable to find a suitable route"
            }
            route.steps.removeAll()
            train.routeStepIndex = 0
            train.startRouteIndex = 0
            return (false, route)
        }
    }

}
