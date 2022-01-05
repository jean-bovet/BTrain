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
    
    var manualRoutes: [Route] {
        return routes.filter({!$0.automatic})
    }
    
    func route(for routeId: Identifier<Route>?, trainId: Identifier<Train>?) -> Route? {
        guard let routeId = routeId else {
            return nil
        }

        if let trainId = trainId, routeId == Route.automaticRouteId(for: trainId), route(for: routeId) == nil {
            // Automatic route, ensure it exists for the train
            let automaticRoute = Route(id: routeId, automatic: true)
            automaticRoute.name = "automatic"
            routes.append(automaticRoute)
            return automaticRoute
        }
        
        return route(for: routeId)
    }
    
    private func route(for routeId: Identifier<Route>?) -> Route? {
        return routes.first(where: { $0.id == routeId })
    }
    
    func newRoute(_ id: String, name: String, automatic: Bool = false, _ steps: [(Block, Direction)]) {
        var routeSteps = [Route.Step]()
        for (index, step) in steps.enumerated() {
            routeSteps.append(Route.Step(String(index), step.0.id, step.1))
        }
        newRoute(id, name: name, automatic: automatic, routeSteps)
    }
    
    @discardableResult
    func newRoute(_ id: String, name: String, automatic: Bool = false, _ steps: [Route.Step]) -> Route {
        let route = Route(uuid: id, automatic: automatic)
        route.name = name
        route.steps = steps
        routes.append(route)
        return route
    }

    func remove(routeId: Identifier<Route>) {
        routes.removeAll { t in
            return t.id == routeId
        }
        trains.forEach { train in
            if train.routeId == routeId {
                train.routeId = nil
            }
        }
    }
    
    @discardableResult
    func updateAutomaticRoute(for trainId: Identifier<Train>, toBlockId: Identifier<Block>?) throws -> Route {
        let routeId = Route.automaticRouteId(for: trainId)
        
        guard let route = route(for: routeId, trainId: trainId) else {
            throw LayoutError.routeNotFound(routeId: routeId)
        }
        
        guard let train = mutableTrain(for: trainId) else {
            throw LayoutError.trainNotFound(trainId: trainId)
        }
        
        guard let blockId = train.blockId else {
            throw LayoutError.trainNotAssignedToABlock(trainId: trainId)
        }
        
        guard let currentBlock = block(for: blockId) else {
            throw LayoutError.blockNotFound(blockId: blockId)
        }
        
        let toBlock: Block?
        if let toBlockId = toBlockId {
            toBlock = block(for: toBlockId)
            guard toBlock != nil else {
                throw LayoutError.blockNotFound(blockId: toBlockId)
            }
        } else {
            toBlock = nil
        }

        guard let trainInstance = currentBlock.train else {
            throw LayoutError.trainNotFoundInBlock(blockId: currentBlock.id)
        }

        // Note: if `toBlock` is specified, always avoid reserved block. Otherwise,
        // just avoid the reserved block in front of the current one but ignore the others
        // (the automatic route will re-evaluate itself it encounters a reserved block later
        // during execution, to avoid deadlocking).
        let settings = PathFinder.Settings(random: automaticRouteRandom,
                                           reservedBlockBehavior: toBlock == nil ? .avoidReservedUntil(numberOfSteps: 1) : .avoidReserved,
                                           verbose: true)
        let pf = PathFinder(layout: self)
        if let path = try pf.path(trainId: train.id, from: currentBlock, toBlock: toBlock, direction: trainInstance.direction, settings: settings) {
            route.steps = path.steps
            train.routeIndex = 0
        }
        return route
    }

    func sortRoutes() {
        routes.sort {
            $0.name < $1.name
        }
    }

}
