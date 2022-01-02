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

// A train is an element that moves from one block to another.
// It can have an associated route to follow.
// This protocol represents an immutable train which should be
// the main way to access its properties.
protocol ITrain: AnyObject {
    // Unique identifier of the train
    var id: Identifier<Train> { get }
    
    // A train that is enabled will show up in the switchboard
    var enabled: Bool { get }
    
    // Name of the train
    var name: String { get }
    
    // Speed of the train
    var speed: UInt16 { get }

    // The route this train is associated with
    var routeId: Identifier<Route>? { get }
        
    // Index of the current block in the route
    // This is important to use an index that is incremented
    // because a route can re-use the same block several times
    // (or the same departing block is also the arrival block)
    var routeIndex: Int { get }
    
    // The block this train is located in
    var blockId: Identifier<Block>? { get }

    // Position of the train inside the current block,
    // represented by an index that identifies after
    // which feedback the train is located.
    // block   : [  f1   f2   f3  ]
    // position:   0   1    2    3
    var position: Int { get }
}

// This mutable implementation of the train is what the layout
// can use to mutate the train state in a coherence manner.
final class Train: Element, ITrain, ObservableObject {
        
    let id: Identifier<Train>
    
    @Published var enabled = true
    
    @Published var name = ""
    
    @Published var address: CommandLocomotiveAddress = .init(0, .MFX)
        
    @Published var speed: UInt16 = 0
        
    @Published var routeId: Identifier<Route>?
    
    @Published var routeIndex = 0
    
    @Published var blockId: Identifier<Block>?
    
    @Published var position = 0
            
    convenience init(uuid: String = UUID().uuidString) {
        self.init(id: Identifier(uuid: uuid))
    }
    
    init(id: Identifier<Train>) {
        self.id = id
    }

}

extension Train: Codable {
    
    enum CodingKeys: CodingKey {
      case id, enabled, name, address, speed, route, routeIndex, block, position
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try container.decode(Identifier<Train>.self, forKey: CodingKeys.id))
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.enabled) ?? true
        self.name = try container.decode(String.self, forKey: CodingKeys.name)
        self.address = try container.decode(CommandLocomotiveAddress.self, forKey: CodingKeys.address)
        self.speed = try container.decode(UInt16.self, forKey: CodingKeys.speed)
        self.routeId = try container.decodeIfPresent(Identifier<Route>.self, forKey: CodingKeys.route)
        self.routeIndex = try container.decode(Int.self, forKey: CodingKeys.routeIndex)
        self.blockId = try container.decodeIfPresent(Identifier<Block>.self, forKey: CodingKeys.block)
        self.position = try container.decode(Int.self, forKey: CodingKeys.position)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(enabled, forKey: CodingKeys.enabled)
        try container.encode(name, forKey: CodingKeys.name)
        try container.encode(address, forKey: CodingKeys.address)
        try container.encode(speed, forKey: CodingKeys.speed)
        try container.encode(routeId, forKey: CodingKeys.route)
        try container.encode(routeIndex, forKey: CodingKeys.routeIndex)
        try container.encode(blockId, forKey: CodingKeys.block)
        try container.encode(position, forKey: CodingKeys.position)
    }

}
