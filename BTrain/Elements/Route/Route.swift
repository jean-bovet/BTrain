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

// A route describes a list of steps describing the various
// block a train will drive through, including the direction
// of travel of the train for each block to avoid ambiguous
// situations where a train can go to a block using more than
// one route (but one route can lead the train to be stuck,
// which we don't want to happen).
// ┌──────────────────────────────────────────────────────┐
// │                                                      │
// │  ┌─────────┐         ┌─────────┐        ┌─────────┐  │
// └─▶│ Block 1 │────────▶│ Block 2 │───────▶│ Block 3 │──┘
//   └─────────┘         └─────────┘        └─────────┘
final class Route: Element, ObservableObject {
    let id: Identifier<Route>

    /// Mode of the route. There are 3 possible modes:
    /// - fixed: the route is created ahead of time by the user and does not change
    /// - automatic: the route is automatically created by BTrain and is updated as the train moves. The train stops only when the user explicitly requests it.
    /// - automaticOnce: like automatic but the train stops at the next station using the shortest path.
    enum Mode: Equatable, Codable {
        // Fixed route specified by the user
        case fixed

        // Run the automatic route as long as the user does not explicitly stop the train
        case automatic

        // Run once the automatic route until it reaches the specified block.
        // The automatic route will try to pick the shortest route.
        case automaticOnce(destination: Destination)
    }

    /// The mode of the route
    var mode = Mode.automatic

    /// Returns true if the route is automatic.
    ///
    /// An automatic route is automatically updated as the train moves in the layout, depending
    /// on the block occupation and constraints of the train.
    var automatic: Bool {
        switch mode {
        case .fixed:
            return false
        case .automaticOnce(_), .automatic:
            return true
        }
    }

    // User-facing name of the route
    @Published var name = ""

    /// The list of partial and unresolved route item as entered by the user.
    ///
    /// That list does not necessary contains all the blocks of a route, which is why
    /// is is called "partial". Before the route can be used, it needs to be completed
    /// in order to find all the missing blocks. See ``steps`` below.
    @Published var partialSteps = [RouteItem]()

    /// The complete list of unresolved route item.
    ///
    /// This list is derived from ``partialSteps`` for fixed routes or automatically filled for automatic route.
    /// Although all the blocks are specified in this array, each item is unresolved.
    ///
    /// - An unresolved step is a step that specify partially an item of
    /// the route; for example, a station is an unresolved step because a station contains one or more
    /// blocks that need to be picked up when the train moves along the route. This is done when
    /// the route is resolved, where each station returns a single block satisfying the constraints of the layout.
    @Published var steps = [RouteItem]()
    
    /// The functions to execute when the route starts
    @Published var startFunctions: RouteItemFunctions?
    
    /// The functions to execute when the route stops
    @Published var stopFunctions: RouteItemFunctions?

    /// The last message about the status of the route, or nil if there is no problem with the route.
    @Published var lastMessage: String?

    var blockSteps: [RouteItemBlock] {
        steps.compactMap {
            if case let .block(stepBlock) = $0 {
                return stepBlock
            } else {
                return nil
            }
        }
    }

    var lastStepIndex: Int {
        steps.count - 1
    }

    convenience init(uuid: String = UUID().uuidString, mode: Route.Mode = .fixed) {
        self.init(id: Identifier(uuid: uuid), mode: mode)
    }

    init(id: Identifier<Route>, mode: Route.Mode = .fixed) {
        self.id = id
        self.mode = mode
    }

    static func automaticRouteId(for trainId: Identifier<Train>) -> Identifier<Route> {
        Identifier<Route>(uuid: "automatic-\(trainId)")
    }
    
    func description(_ layout: Layout) -> String {
        var info = "\(name)-[\(id)]"
        switch mode {
        case let .automaticOnce(destination: destination):
            info += " (automatic once to \(destination.blockId), direction \(String(describing: destination.direction))"
        case .automatic:
            info += " (automatic mode)"
        case .fixed:
            info += " (fixed)"
        }
        
        if steps.isEmpty {
            info += ". No steps defined."
        } else {
            info += ". \(steps.count) steps: ["
            info += steps.map({ "(\($0.description(layout)))"}).joined(separator: ",")
            info += "]"
        }
        return info
    }
}

extension Route: Codable {
    enum CodingKeys: CodingKey {
        case id, name, steps, stepsv2, items, automatic, mode, startFunctions, stopFunctions
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(Identifier<Route>.self, forKey: CodingKeys.id)
        let mode: Route.Mode
        if let m = try container.decodeIfPresent(Route.Mode.self, forKey: CodingKeys.mode) {
            mode = m
        } else {
            mode = .fixed
        }
        self.init(id: id, mode: mode)
        name = try container.decode(String.self, forKey: CodingKeys.name)
        if container.contains(CodingKeys.steps) {
            partialSteps = try container.decode([RouteStep_v1].self, forKey: CodingKeys.steps).toRouteSteps
        } else if container.contains(CodingKeys.stepsv2) {
            partialSteps = try container.decode([RouteItem].self, forKey: CodingKeys.stepsv2)
        } else if container.contains(CodingKeys.items) {
            partialSteps = try container.decode([RouteItem].self, forKey: CodingKeys.items)
        }
        startFunctions = try container.decodeIfPresent(RouteItemFunctions.self, forKey: CodingKeys.startFunctions)
        stopFunctions = try container.decodeIfPresent(RouteItemFunctions.self, forKey: CodingKeys.stopFunctions)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(name, forKey: CodingKeys.name)
        try container.encode(partialSteps, forKey: CodingKeys.items)
        try container.encode(mode, forKey: CodingKeys.mode)
        try container.encode(startFunctions, forKey: CodingKeys.startFunctions)
        try container.encode(stopFunctions, forKey: CodingKeys.stopFunctions)
    }
}
