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

/// A layout is an object that represents a train layout.
///
/// A train layout consists of the following elements:
/// - blocks
/// - turnouts
/// - feedbacks
/// - train
/// - locomotive
/// - routes
///
/// Note: this class is the only one that should mutate the element of the
/// layout in order to preserve consistency and code maintenance.
final class Layout: Element, ObservableObject {
    
    /// The unique identifier of this layout
    let id: Identifier<Layout>
    
    /// The name of the layout
    var name = ""
    
    /// A container holding the blocks
    @Published var blocks = LayoutElementContainer<Block>()
    
    /// A container holding the stations
    @Published var stations = LayoutElementContainer<Station>()
    
    /// An array of feedbacks
    @Published var feedbacks = LayoutElementContainer<Feedback>()
    
    /// An array of turnouts
    @Published var turnouts = LayoutElementContainer<Turnout>()
    
    /// A container holding the trains
    @Published var trains = LayoutElementContainer<Train>()
    
    /// A container holding the locomotives
    @Published var locomotives = LayoutElementContainer<Locomotive>()
    
    /// An array of transitions.
    ///
    /// A transition links two blocks or turnouts together.
    @Published var transitions = [Transition]()
    
    /// Array of optional control points that the user has defined for a particular transition. By default, this array is empty
    /// because the transition automatically create their control point given the positions of the origin and target element.
    /// However, the user is free to move these control points for greater flexibility and when this happens, these custom
    /// control points are stored in this array.
    @Published var controlPoints = [ControlPoint]()
    
    /// A container holding the route scripts
    @Published var routeScripts = LayoutElementContainer<RouteScript>()

    /// A container holding the layout scripts
    @Published var layoutScripts = LayoutElementContainer<LayoutScript>()

    /// An array of routes.
    ///
    /// A route can be defined by the users (fixed) or generated automatically (automatic).
    /// Automatic routes have a special ID that follows the pattern `automatic-<trainId>`
    @Published var routes = [Route]()
            
    /// True if the automatic routes are created
    /// using a random path or false if they are
    /// created using the first-search approach which
    /// always give the same result - useful for unit tests.
    @AppStorage(SettingsKeys.automaticRouteRandom) var automaticRouteRandom = true

    /// True if unexpected feedback should be detected and the layout stopped.
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
        
    // MARK: Init
    
    convenience init(uuid: String = UUID().uuidString) {
        self.init(id: Identifier(uuid: uuid))
    }

    init(id: Identifier<Layout>) {
        self.id = id
    }

    func apply(other: Layout) {
        self.blocks = other.blocks
        self.stations = other.stations
        self.feedbacks = other.feedbacks
        self.turnouts = other.turnouts
        self.transitions = other.transitions
        self.controlPoints = other.controlPoints
        self.routes = other.routes
        self.layoutScripts = other.layoutScripts
        self.routeScripts = other.routeScripts
        self.trains = other.trains
        self.locomotives = other.locomotives
    }
    
    func trainsThatCanBeStarted() -> [Train] {
        trains.elements.filter { train in
            train.enabled && train.blockId != nil && train.scheduling == .unmanaged
        }
    }
    
    func trainsThatCanBeStopped() -> [Train] {
        trains.elements.filter { train in
            train.scheduling == .managed || train.scheduling == .finishManaged
        }
    }
    
    func trainsThatCanBeFinished() -> [Train] {
        trains.elements.filter { train in
            train.scheduling == .managed
        }
    }
}

// MARK: Codable

extension Layout: Codable {
    
    enum CodingKeys: CodingKey {
        case id, name, blocks, stations, feedbacks, turnouts, trains, locomotives, routes, layoutScripts, routeScripts, transitions, controlPoints
        
        // TODO: deprecated
        case scripts
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try container.decode(Identifier<Layout>.self, forKey: CodingKeys.id))
        self.name = try container.decode(String.self, forKey: CodingKeys.name)
        if let blocks = try? container.decode([Block].self, forKey: CodingKeys.blocks) {
            self.blocks.elements = blocks
        } else {
            self.blocks = try container.decode(LayoutElementContainer<Block>.self, forKey: CodingKeys.blocks)
        }
        if let stations = try? container.decode([Station].self, forKey: CodingKeys.stations) {
            self.stations.elements = stations
        } else {
            self.stations = try container.decode(LayoutElementContainer<Station>.self, forKey: CodingKeys.stations)
        }
        if let feedbacks = try? container.decode([Feedback].self, forKey: CodingKeys.feedbacks) {
            self.feedbacks.elements = feedbacks
        } else {
            self.feedbacks = try container.decode(LayoutElementContainer<Feedback>.self, forKey: CodingKeys.feedbacks)
        }
        if let turnouts = try? container.decode([Turnout].self, forKey: CodingKeys.turnouts) {
            self.turnouts.elements = turnouts
        } else {
            self.turnouts = try container.decode(LayoutElementContainer<Turnout>.self, forKey: CodingKeys.turnouts)
        }
        if let trains = try? container.decode([Train].self, forKey: CodingKeys.trains) {
            self.trains.elements = trains
        } else {
            self.trains = try container.decode(LayoutElementContainer<Train>.self, forKey: CodingKeys.trains)
        }
        if let locomotives = try? container.decode([Locomotive].self, forKey: CodingKeys.locomotives) {
            self.locomotives.elements = locomotives
        } else {
            self.locomotives = try container.decode(LayoutElementContainer<Locomotive>.self, forKey: CodingKeys.locomotives)
        }
        self.routes = try container.decode([Route].self, forKey: CodingKeys.routes)
        self.layoutScripts = try container.decodeIfPresent(LayoutElementContainer<LayoutScript>.self, forKey: CodingKeys.layoutScripts) ?? LayoutElementContainer<LayoutScript>()

        // TODO: update all the files and move away from this key
        if let routeScripts = try container.decodeIfPresent([RouteScript].self, forKey: CodingKeys.scripts) {
            self.routeScripts.elements = routeScripts
        } else {
            self.routeScripts = try container.decodeIfPresent(LayoutElementContainer<RouteScript>.self, forKey: CodingKeys.routeScripts) ?? LayoutElementContainer<RouteScript>()
        }
        self.transitions = try container.decode([Transition].self, forKey: CodingKeys.transitions)
        self.controlPoints = try container.decode([ControlPoint].self, forKey: CodingKeys.controlPoints)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(name, forKey: CodingKeys.name)
        try container.encode(blocks, forKey: CodingKeys.blocks)
        try container.encode(stations, forKey: CodingKeys.stations)
        try container.encode(feedbacks, forKey: CodingKeys.feedbacks)
        try container.encode(turnouts, forKey: CodingKeys.turnouts)
        try container.encode(trains, forKey: CodingKeys.trains)
        try container.encode(locomotives, forKey: CodingKeys.locomotives)
        try container.encode(fixedRoutes, forKey: CodingKeys.routes)
        try container.encode(layoutScripts, forKey: CodingKeys.layoutScripts)
        try container.encode(routeScripts, forKey: CodingKeys.routeScripts)
        try container.encode(transitions, forKey: CodingKeys.transitions)
        try container.encode(controlPoints, forKey: CodingKeys.controlPoints)
    }
    
    // TODO: used for what exactly?
    static func decode(from data: Data) throws -> Layout {
        let decoder = JSONDecoder()
        let layout = try decoder.decode(Layout.self, from: data)
        return layout
    }
    
    // TODO: used for what exactly?
    func encode() throws -> Data {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        return data
    }
    
}
