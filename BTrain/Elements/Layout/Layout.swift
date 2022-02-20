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
    
    @Published var blockMap = OrderedDictionary<Identifier<Block>, Block>()

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

    // The command executor used to execute command towards the Digital Controller.
    var executor: LayoutCommandExecutor?
    
    // Non-nil when a layout runtime error occurred
    @Published var runtimeError: String?

    lazy var reservation: LayoutReservation = {
        return LayoutReservation(layout: self)
    }()
    
    lazy var automaticRouting: AutomaticRouting = {
        return AutomaticRouting(layout: self)
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
        self.feedbacks = other.feedbacks
        self.turnouts = other.turnouts
        self.transitions = other.transitions
        self.routes = other.routes
        self.trains = other.trains
    }
    
    func trainsThatCanBeStarted() -> [Train] {
        return trains.filter { train in
            return train.enabled && train.blockId != nil && train.routeId != nil && train.manualScheduling
        }
    }
    
    func trainsThatCanBeStopped() -> [Train] {
        return trains.filter { train in
            return train.automaticScheduling
        }
    }
    
    func trainsThatCanBeFinished() -> [Train] {
        return trains.filter { train in
            return train.automaticScheduling && !train.automaticFinishingScheduling
        }
    }
    
    // Returns true if the specified train can be considered at a valid
    // location to be monitored to move to the next block.
    func shouldHandleTrainMoveToNextBlock(train: Train) throws -> Bool {
        // There must exist a next block
        guard let nextBlock = nextBlock(train: train) else {
            return false
        }
        
        // The next block should either be reserved for this train or free
        guard nextBlock.reserved?.trainId == train.id || nextBlock.reserved == nil else {
            return false
        }
        
        if strictRouteFeedbackStrategy {
            // Strict route stratey requires the train to be at the end of the block
            // before moving to the next block.
            return try atEndOfBlock(train: train)
        } else {
            return true
        }
    }
    
    // Programmatically trigger a change event for the layout,
    // which is used by other object, such as the switchboard,
    // to re-draw itself. This is necessary because changes
    // in children parameters of the layout (ie the speed of a train),
    // is not propagated to the layout object itself.
    func didChange() {
        objectWillChange.send()
    }
    
    // MARK: Identity
    
    static func newIdentity<T>(_ elements: OrderedDictionary<Identifier<T>, T>) -> Identifier<T> {
        var index = 1
        var id = Identifier<T>(uuid: String(index))
        while elements[id] != nil {
            index += 1
            id = Identifier<T>(uuid: String(index))
        }
        return id
    }
    
    static func newIdentity<T:ElementUUID>(_ elements: [T]) -> String {
        var index = 1
        var id = String(index)
        while elements.first(where: { $0.uuid == id }) != nil {
            index += 1
            id = String(index)
        }
        return id
    }

}

// MARK: Codable

extension Layout: Codable {
    
    enum CodingKeys: CodingKey {
      case id, name, blocks, feedbacks, turnouts, trains, routes, transitions
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try container.decode(Identifier<Layout>.self, forKey: CodingKeys.id))
        self.name = try container.decode(String.self, forKey: CodingKeys.name)
        self.blocks = try container.decode([Block].self, forKey: CodingKeys.blocks)
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
        try container.encode(blocks, forKey: CodingKeys.blocks)
        try container.encode(feedbacks, forKey: CodingKeys.feedbacks)
        try container.encode(turnouts, forKey: CodingKeys.turnouts)
        try container.encode(trains, forKey: CodingKeys.trains)
        try container.encode(manualRoutes, forKey: CodingKeys.routes)
        try container.encode(transitions, forKey: CodingKeys.transitions)
    }
    
}
