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
//┌──────────────────────────────────────────────────────┐
//│                                                      │
//│  ┌─────────┐         ┌─────────┐        ┌─────────┐  │
//└─▶│ Block 1 │────────▶│ Block 2 │───────▶│ Block 3 │──┘
//   └─────────┘         └─────────┘        └─────────┘
final class Route: Element, ObservableObject {
        
    let id: Identifier<Route>
    
    /// Mode of the route. There are 3 possible modes:
    /// - fixed: the route is created ahead of time by the user and does not change
    /// - automatic: the route is automatically created by BTrain and is updated as the train moves. The train stops only when the user explicitely requests it.
    /// - automaticOnce: like automatic but the train stops at the next station using the shortest path.
    enum Mode: Equatable, Codable {
        // Fixed route specified by the user
        case fixed
                
        // Run the automatic route as long as the user does not explicitely stop the train
        case automatic
        
        // Run onces the automatic route until it reaches the specified block.
        // The automatic route will try to pick the shortest route.
        case automaticOnce(destination: Destination)
    }
    
    // When automatic is true, this defines the mode in which
    // the automatic route is defined.
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
        
    /// The list of unresolved steps. An unresolved step is a step that specify partially an item of
    /// the route; for example, a station is an unresolved step because a station contains one or more
    /// blocks that need to be picked up when the train moves along the route. This is done when
    /// the route is resolved, where each station returns a single block satisfying the constraints of the layout.
    @Published var steps = [RouteItem]()
    
    /// The last message about the status of the route, or nil if there is no problem with the route.
    @Published var lastMessage: String?
    
    var blockSteps: [RouteStepBlock] {
        return steps.compactMap {
            if case .block(let stepBlock) = $0 {
                return stepBlock
            } else {
                return nil
            }
        }
    }

    var lastStepIndex: Int {
        return steps.count - 1
    }
    
    convenience init(uuid: String = UUID().uuidString, mode: Route.Mode = .fixed) {
        self.init(id: Identifier(uuid: uuid), mode: mode)
    }
    
    init(id: Identifier<Route>, mode: Route.Mode = .fixed) {
        self.id = id
        self.mode = mode
    }
    
    /// Resolve this route by filling the ``resolvedSteps`` with all the steps of the route.
    ///
    /// Resolving a route means that all the steps of a route are resolved:
    /// - Station is resolved by picking the best block according to the specified constraints
    /// - Missing block and turnout between two steps are resolved by respecting the current constraints of the layout
    /// - Parameters:
    ///   - layout: the layout
    ///   - train: the train to use to resolve the route. A train is important because it can limit which blocks or turnouts can be used if the train has specific constraints.
    /// - Returns: true if the route could be resolved, false otherwise.
    func resolve(layout: Layout, train: Train) throws -> [ResolvedRouteItem]? {
        var errors = [GraphPathFinder.ResolverError]()
        guard let resolvedSteps = try RouteResolver(layout: layout, train: train).resolve(steps: ArraySlice(steps), errors: &errors, verbose: false) else {
            return nil
        }
        return resolvedSteps
    }

    static func automaticRouteId(for trainId: Identifier<Train>) -> Identifier<Route> {
        return Identifier<Route>(uuid: "automatic-\(trainId)")
    }
}

extension Route: Codable {
    
    enum CodingKeys: CodingKey {
        case id, name, steps, stepsv2, automatic, mode
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(Identifier<Route>.self, forKey: CodingKeys.id)
        let mode: Route.Mode
        if let value = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.automatic), value == true {
            mode = .automatic
        } else if let m = try container.decodeIfPresent(Route.Mode.self, forKey: CodingKeys.mode) {
            mode = m
        } else {
            mode = .fixed
        }
        self.init(id: id, mode: mode)
        self.name = try container.decode(String.self, forKey: CodingKeys.name)
        if container.contains(CodingKeys.steps) {
            self.steps = try container.decode([RouteStep_v1].self, forKey: CodingKeys.steps).toRouteSteps
        } else {
            self.steps = try container.decode([RouteItem].self, forKey: CodingKeys.stepsv2)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(name, forKey: CodingKeys.name)
        try container.encode(steps, forKey: CodingKeys.stepsv2)
        try container.encode(mode, forKey: CodingKeys.mode)
    }

}
