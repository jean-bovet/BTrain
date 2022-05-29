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
    
    var fixedRoutes: [Route] {
        routes.filter({ !$0.automatic })
    }
    
    func route(for routeId: Identifier<Route>, trainId: Identifier<Train>?) -> Route? {
        if let trainId = trainId, routeId == Route.automaticRouteId(for: trainId), route(for: routeId) == nil {
            // Automatic route, ensure it exists for the train
            let automaticRoute = Route(id: routeId, mode: .automatic)
            automaticRoute.name = "automatic"
            routes.append(automaticRoute)
            return automaticRoute
        }
        
        return route(for: routeId)
    }
    
    private func route(for routeId: Identifier<Route>?) -> Route? {
        routes.first(where: { $0.id == routeId })
    }
    
    func newRoute(_ id: String, name: String, _ steps: [(Block, Direction, TimeInterval?)]) -> Route {
        var routeSteps = [RouteItem]()
        for step in steps {
            routeSteps.append(.block(RouteStepBlock(step.0.id, step.1, step.2)))
        }
        return newRoute(Identifier<Route>(uuid: id), name: name, routeSteps)
    }
    
    func newRoute() -> Route {
        newRoute(LayoutIdentity.newIdentity(routes, prefix: .route), name: "", [])
    }
    
    func newRoute(_ id: Identifier<Route>, name: String, _ steps: [RouteItem]) -> Route {
        let route = Route(id: id)
        route.name = name
        route.steps = steps
        routes.append(route)
        return route
    }

    func remove(routeId: Identifier<Route>) {
        routes.removeAll { t in
            t.id == routeId
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
    
    func routeDescription(for train: Train) -> String {
        var text = ""
        if let route = self.route(for: train.routeId, trainId: train.id),
           let train = self.train(for: train.id) {
            if let message = route.lastMessage {
                text = message
            } else {
                var index = 0
                for step in route.steps {
                    guard let description = self.description(of: step) else {
                        continue
                    }
                    
                    if !text.isEmpty {
                        text += "→"
                    }
                    
                    text += description
                    
                    if train.routeStepIndex == index {
                        // Indicate the block in the route where the train
                        // is currently located
                        text += "􀼮"
                    }
                    
                    index += 1
                }
            }
        }
        return text
    }
    
    func description(of item: RouteItem) -> String? {
        switch item {
        case .block(let stepBlock):
            return description(of: stepBlock.blockId)

        case .station(let stepStation):
            if let station = station(for: stepStation.stationId) {
                return "\(station.name)"
            } else {
                return "\(stepStation.stationId)"
            }
            
        case .turnout(_):
            return nil
        }
    }
    
    func description(of blockId: Identifier<Block>) -> String {
        if let block = block(for: blockId) {
            return "\(block.name)"
        } else {
            return "\(blockId)"
        }
    }
    
    var defaultRouteDescription: String {
        "􀼮→"
    }
            
}
