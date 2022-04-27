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
    
    func route(for routeId: Identifier<Route>, trainId: Identifier<Train>?) -> Route? {
        if let trainId = trainId, routeId == Route.automaticRouteId(for: trainId), route(for: routeId) == nil {
            // Automatic route, ensure it exists for the train
            let automaticRoute = Route(id: routeId, automatic: true)
            automaticRoute.automaticMode = .endless
            automaticRoute.name = "automatic"
            routes.append(automaticRoute)
            return automaticRoute
        }
        
        return route(for: routeId)
    }
    
    private func route(for routeId: Identifier<Route>?) -> Route? {
        return routes.first(where: { $0.id == routeId })
    }
    
    func newRoute(_ id: String, name: String, automatic: Bool = false, _ steps: [(Block, Direction, TimeInterval?)]) {
        var routeSteps = [RouteItem]()
        for (index, step) in steps.enumerated() {
            routeSteps.append(.block(RouteStep_Block(String(index), step.0.id, step.1, step.2)))
        }
        newRoute(id, name: name, automatic: automatic, routeSteps)
    }
    
    @discardableResult
    func newRoute(_ id: String, name: String, automatic: Bool = false, _ steps: [RouteItem]) -> Route {
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
                train.routeId = Route.automaticRouteId(for: train.id)
            }
        }
    }
    
    func sortRoutes() {
        routes.sort {
            $0.name < $1.name
        }
    }

}
