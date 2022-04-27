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
    
    // True if the route is automatically generated,
    // which means that if the train cannot continue
    // to follow it, a new one will be generated
    let automatic: Bool
    
    enum AutomaticMode: Equatable {
        // Run onces the automatic route until it reaches the specified block.
        // The automatic route will try to pick the shortest route.
        case once(destination: Destination)
        
        // Run the automatic route as long as the user does not explicitely stop the train
        case endless
    }
    
    // When automatic is true, this defines the mode in which
    // the automatic route is defined.
    var automaticMode = AutomaticMode.endless
    
    // User-facing name of the route
    @Published var name = ""
    
    // The list of steps for this route
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
    
    convenience init(uuid: String = UUID().uuidString, automatic: Bool = false) {
        self.init(id: Identifier(uuid: uuid), automatic: automatic)
    }
    
    init(id: Identifier<Route>, automatic: Bool = false) {
        self.id = id
        self.automatic = automatic
    }

    static func automaticRouteId(for trainId: Identifier<Train>) -> Identifier<Route> {
        return Identifier<Route>(uuid: "automatic-\(trainId)")
    }
}

extension Route: Codable {
    
    enum CodingKeys: CodingKey {
      case id, name, steps, stepsv2, automatic
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(Identifier<Route>.self, forKey: CodingKeys.id)
        let automatic = try container.decode(Bool.self, forKey: CodingKeys.automatic)
        self.init(id: id, automatic: automatic)
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
        try container.encode(automatic, forKey: CodingKeys.automatic)
    }

}
