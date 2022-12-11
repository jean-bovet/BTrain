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
    case missingStartCommand
    case undefinedBlock(command: RouteScriptCommand)
    case undefinedDirection(command: RouteScriptCommand)
    case undefinedStation(command: RouteScriptCommand)
}

extension ScriptError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingStartCommand:
            return "The first command should be the `start` command"
        case .undefinedBlock:
            return "Block is undefined"
        case .undefinedDirection:
            return "Direction is undefined"
        case .undefinedStation:
            return "Station is undefined"
        }
    }
}

extension RouteScript {
    /// Creates a route representing the script. The route ID will be the same as the script ID.
    ///
    /// - Returns: a new route
    func toRoute() throws -> Route {
        guard commands.first?.action == .start else {
            throw ScriptError.missingStartCommand
        }
        let route = Route(uuid: id.uuid, mode: .fixed)
        route.name = name
        route.partialSteps.append(contentsOf: try commands.toRouteItems())
        return route
    }
}

extension RouteScriptCommand {
    
    /// Returns the functions for a route item
    var routeItemFunctions: RouteItemFunctions {
        RouteItemFunctions(functions: functions.map({ RouteItemFunctions.Function(type: $0.type, enabled: $0.enabled, duration: .init(wrappedValue: $0.duration) ) }))
    }

    func toBlockItem() throws -> RouteItem {
        guard let blockId = blockId else {
            throw ScriptError.undefinedBlock(command: self)
        }

        guard let direction = direction else {
            throw ScriptError.undefinedDirection(command: self)
        }

        var item = RouteItemBlock(blockId, direction, TimeInterval(waitDuration))
        item.functions = routeItemFunctions
        
        // Assign to the route item the id of the script command. That way,
        // when an error happens during route resolving, we can easily map
        // the error to the original script command and highlight it in the UI.
        item.sourceIdentifier = id.uuidString
        
        return .block(item)
    }

    func toRouteItems() throws -> [RouteItem] {
        switch action {
        case .start:
            return [try toBlockItem()]

        case .move:
            switch destinationType {
            case .block:
                return [try toBlockItem()]
            case .station:
                if let stationId = stationId {
                    return [.station(.init(stationId: stationId, functions: routeItemFunctions))]
                } else {
                    throw ScriptError.undefinedStation(command: self)
                }
            }
            
        case .loop:
            var items = [RouteItem]()
            for _ in 1 ... repeatCount {
                let routeItems = try children.toRouteItems()
                items.append(contentsOf: routeItems)
            }
            return items            
        }
    }

}

extension Array where Element == RouteScriptCommand {
    func toRouteItems() throws -> [RouteItem] {
        var items = [RouteItem]()
        try forEach { cmd in
            let routeItems = try cmd.toRouteItems()
            items.append(contentsOf: routeItems)
        }
        return items
    }
}
