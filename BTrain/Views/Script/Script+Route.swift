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

enum ScriptError: Error {
    case undefinedBlock(command: ScriptCommand)
    case undefinedDirection(command: ScriptCommand)
    case undefinedStation(command: ScriptCommand)
}

extension ScriptError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .undefinedBlock(_):
            return "Block is undefined"
        case .undefinedDirection(_):
            return "Direction is undefined"
        case .undefinedStation(_):
            return "Station is undefined"
        }
    }
}

extension Script {
    
    func toRoute() throws -> Route {
        let route = Route()
        route.partialSteps.append(contentsOf: try commands.toRouteItems())
        return route
    }
        
}

extension ScriptCommand {
    
    func toRouteItems() throws -> [RouteItem] {
        switch action {
        case .move:
            switch destinationType {
            case .block:
                guard let direction = direction else {
                    throw ScriptError.undefinedDirection(command: self)
                }
                
                guard let blockId = blockId else {
                    throw ScriptError.undefinedBlock(command: self)
                }
                
                var item = RouteItemBlock(blockId, direction, TimeInterval(waitDuration))
                // Assign to the route item the id of the script command. That way,
                // when an error happens during route resolving, we can easily map
                // the error to the original script command and highlight it in the UI.
                item.sourceIdentifier = id.uuidString
                return [.block(item)]
            case .station:
                if let stationId = stationId {
                    return [.station(.init(stationId: stationId))]
                } else {
                    throw ScriptError.undefinedStation(command: self)
                }
            }
        case .loop:
            var items = [RouteItem]()
            for _ in 1...repeatCount {
                let routeItems = try children.toRouteItems()
                items.append(contentsOf: routeItems)
            }
            return items
        }
    }
}

extension Array where Element == ScriptCommand {
    
    func toRouteItems() throws -> [RouteItem] {
        var items = [RouteItem]()
        try forEach { cmd in
            let routeItems = try cmd.toRouteItems()
            items.append(contentsOf: routeItems)
        }
        return items
    }
}
