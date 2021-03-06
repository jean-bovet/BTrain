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
import OrderedCollections
import SwiftUI

// A layout is an object that represents an actual train layout,
// with blocks, turnouts, feedbacks, trains and transitions
// between the blocks and turnouts. It also includes routes
// that can be assigned to train.
//
// This class is the only one that should mutate the element of the
// layout in order to preserve consistency and code maintenance.
final class Layout: Element, ObservableObject {
        
    let id: Identifier<Layout>
    
    var name = ""

    @Published var newLayoutWizardExecuted = false
    
    @Published var blockMap = OrderedDictionary<Identifier<Block>, Block>()

    @Published var stationMap = OrderedDictionary<Identifier<Station>, Station>()

    @Published var feedbacks = [Feedback]()
    
    @Published var turnouts = [Turnout]()
    
    @Published var trains = [Train]()
    
    @Published var transitions = [Transition]()

    // Note: automatic route have a special ID that follows this pattern:
    // "automatic-<trainId>"
    @Published var routes = [Route]()
            
    // True if the automatic routes are created
    // using a random path or false if they are
    // created using the first-search approach which
    // always give the same result - useful for unit tests.
    @AppStorage(SettingsKeys.automaticRouteRandom) var automaticRouteRandom = true

    // True if unexpected feedback should be detected and the layout stopped.
    @AppStorage(SettingsKeys.detectUnexpectedFeedback) var detectUnexpectedFeedback = true
    
    // Defines the route feedback strategy:
    // If true, then:
    // - The train position is updated only when the feedback in front of the train is detected
    //   (within the current block). Any feedback behind the train inside the current block is ignored.
    // - The train moves to the next block only when the train is located at the end of the
    //   current block *and* the feedback in the next block is the first one in the direction
    //   of travel of the train.
    //
    // If false, then:
    // - The train position is updated when any feedback in front of the train is detected
    //   (within the current block). Any feedback behind the train inside the current block is ignored.
    // - The train moves to the next block when the feedback in the next block is the first one in the direction
    //   of travel of the train. The train does not need to be at the end of the current block for this to happen.
    @AppStorage(SettingsKeys.strictRouteFeedbackStrategy) var strictRouteFeedbackStrategy = false
    
    // Non-nil when a layout runtime error occurred
    @Published var runtimeError: String?
    
    lazy var automaticRouting: AutomaticRouting = {
        AutomaticRouting(layout: self)
    }()
    
    // MARK: Init
    
    convenience init(uuid: String = UUID().uuidString) {
        self.init(id: Identifier(uuid: uuid))
    }

    init(id: Identifier<Layout>) {
        self.id = id
    }

    func apply(other: Layout) {
        self.blockMap = other.blockMap
        self.stations = other.stations
        self.feedbacks = other.feedbacks
        self.turnouts = other.turnouts
        self.transitions = other.transitions
        self.routes = other.routes
        self.trains = other.trains
    }
    
    func trainsThatCanBeStarted() -> [Train] {
        trains.filter { train in
            train.enabled && train.blockId != nil && train.scheduling == .unmanaged
        }
    }
    
    func trainsThatCanBeStopped() -> [Train] {
        trains.filter { train in
            train.scheduling == .managed || train.scheduling == .finishManaged
        }
    }
    
    func trainsThatCanBeFinished() -> [Train] {
        trains.filter { train in
            train.scheduling == .managed
        }
    }
}

// MARK: Codable

extension Layout: Codable {
    
    enum CodingKeys: CodingKey {
      case id, name, newLayoutWizardExecuted, blocks, stations, feedbacks, turnouts, trains, routes, transitions
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try container.decode(Identifier<Layout>.self, forKey: CodingKeys.id))
        self.name = try container.decode(String.self, forKey: CodingKeys.name)
        self.newLayoutWizardExecuted = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.newLayoutWizardExecuted) ?? true
        self.blocks = try container.decode([Block].self, forKey: CodingKeys.blocks)
        self.stations = try container.decodeIfPresent([Station].self, forKey: CodingKeys.stations) ?? []
        self.feedbacks = try container.decode([Feedback].self, forKey: CodingKeys.feedbacks)
        self.turnouts = try container.decode([Turnout].self, forKey: CodingKeys.turnouts)
        self.trains = try container.decode([Train].self, forKey: CodingKeys.trains)
        self.routes = try container.decode([Route].self, forKey: CodingKeys.routes)
        self.transitions = try container.decode([Transition].self, forKey: CodingKeys.transitions)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(name, forKey: CodingKeys.name)
        try container.encode(newLayoutWizardExecuted, forKey: CodingKeys.newLayoutWizardExecuted)
        try container.encode(blocks, forKey: CodingKeys.blocks)
        try container.encode(stations, forKey: CodingKeys.stations)
        try container.encode(feedbacks, forKey: CodingKeys.feedbacks)
        try container.encode(turnouts, forKey: CodingKeys.turnouts)
        try container.encode(trains, forKey: CodingKeys.trains)
        try container.encode(fixedRoutes, forKey: CodingKeys.routes)
        try container.encode(transitions, forKey: CodingKeys.transitions)
    }
    
    func restore(from data: Data) throws {
        apply(other: try Layout.decode(from: data))
    }
    
    static func decode(from data: Data) throws -> Layout {
        let decoder = JSONDecoder()
        let layout = try decoder.decode(Layout.self, from: data)
        return layout
    }
    
    func encode() throws -> Data {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        return data
    }
    
}
