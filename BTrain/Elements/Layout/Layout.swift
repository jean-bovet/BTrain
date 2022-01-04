// Copyright 2021 Jean Bovet
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
    
    @Published var mutableBlocks = OrderedDictionary<Identifier<Block>, Block>()

    @Published var feedbacks = [Feedback]()
    
    @Published var turnouts = [Turnout]()
    
    @Published var mutableTrains = [Train]()
    
    // Note: automatic route have a special ID that follows this pattern:
    // "automatic-<trainId>"
    @Published var routes = [Route]()
            
    // True if the automatic routes are created
    // using a random path or false if they are
    // created using the first-search approach which
    // always give the same result - useful for unit tests.
    // TODO: expose that as a settings option
    var automaticRouteRandom = true
    
    var transitions = [Transition]()
    
    var interface: CommandInterface?
    
    // MARK: Handlers
        
    lazy var transitionHandling: LayoutTransitionHandling = {
        return LayoutTransitionHandler(layout: self)
    }()

    lazy var trainHandling: LayoutTrainHandling = {
        return LayoutTrainHandler(layout: self, layoutTransitionController: transitionHandling, exec: self)
    }()

    lazy var routeHandling: LayoutRouteHandling = {
        return LayoutRouteHandler(layout: self, trainController: trainHandling)
    }()

    // MARK: Init
    
    convenience init(uuid: String = UUID().uuidString) {
        self.init(id: Identifier(uuid: uuid))
    }

    init(id: Identifier<Layout>) {
        self.id = id
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
        self.mutableBlockArray = try container.decode([Block].self, forKey: CodingKeys.blocks)
        self.feedbacks = try container.decode([Feedback].self, forKey: CodingKeys.feedbacks)
        self.turnouts = try container.decode([Turnout].self, forKey: CodingKeys.turnouts)
        self.mutableTrains = try container.decode([Train].self, forKey: CodingKeys.trains)
        self.routes = try container.decode([Route].self, forKey: CodingKeys.routes)
        self.transitions = try container.decode([Transition].self, forKey: CodingKeys.transitions)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(name, forKey: CodingKeys.name)
        try container.encode(mutableBlockArray, forKey: CodingKeys.blocks)
        try container.encode(feedbacks, forKey: CodingKeys.feedbacks)
        try container.encode(turnouts, forKey: CodingKeys.turnouts)
        try container.encode(mutableTrains, forKey: CodingKeys.trains)
        try container.encode(manualRoutes, forKey: CodingKeys.routes)
        try container.encode(transitions, forKey: CodingKeys.transitions)
    }
    
}
