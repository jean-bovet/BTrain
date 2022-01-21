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

// A train is an element that moves from one block to another.
// Currently we make no difference between a train and a locomotive,
// they are the same.
final class Train: Element, ObservableObject {
    // Unique identifier of the train
    let id: Identifier<Train>
    
    // A train that is enabled will show up in the switchboard
    @Published var enabled = true
    
    // Name of the train
    @Published var name = ""
    
    // The URL of the train icon to load
    @Published var iconUrlData: Data?
    
    // Address of the train
    @Published var address: UInt32 = 0
      
    // The decoder type of this train
    @Published var decoder: DecoderType = .MFX {
        didSet {
            speed.decoderType = decoder
        }
    }
    
    // Speed of the train
    @Published var speed = TrainSpeed(kph: 0, decoderType: .MFX)

    // Direction of travel of the train
    @Published var directionForward = true
    
    // The route this train is associated with
    @Published var routeId: Identifier<Route>?
    
    // Index of the current route step that the train is located in.
    @Published var routeStepIndex = 0

    // Array of trailing route steps that are kept reserved as the train
    // moves through the route. When the train moves far enough,
    // the furthest block (defined in the step) from the train is getting released.
    @Published var trailingReservedBlocks = [Route.Step]()
    
    // Number of blocks the route should keep reserved behind
    // the train as it moves throught the route. The default is 0,
    // but can be changed for long train that can span more than
    // one block. In the future, when length of blocks and trains are
    // taken into consideration, this will become a more dynamic property.
    @Published var numberOfTrailingReservedBlocks = 0
    
    // The maximum number of blocks that should be reserved ahead of the train.
    // The actual number of blocks might be smaller if a block cannot be reserved.
    // The default is 1.
    @Published var maxNumberOfLeadingReservedBlocks = 1
    
    enum Schedule {
        // The train is stopped and cannot be started again
        // unless the user takes an explicit action (ie Start button)
        case stopped
        
        // The train is running and has not yet finished the route
        // Note: a train can be "stopped" with a speed of 0 kph while still
        // be in a running state. This happens when the train stops because
        // the next block is occupied or it has reached a station.
        case running
        
        // The train is running and will stop when it finishes the route
        case finishing
    }
    
    // The state of the schedule
    @Published var scheduling: Schedule = .stopped
    
    enum State {
        case running
        case braking
        case stopped
    }
    
    // The state of the train
    @Published var state: State = .stopped

    //var brakeInBlock
    // The block this train is located in
    @Published var blockId: Identifier<Block>?
    
    // Position of the train inside the current block,
    // represented by an index that identifies after
    // which feedback the train is located.
    // block   : [  f1   f2   f3  ]
    // position:   0   1    2    3
    @Published var position = 0
            
    var description: String {
        return "\(name) (\(id))"
    }
    
    convenience init(uuid: String = UUID().uuidString) {
        self.init(id: Identifier(uuid: uuid))
    }
    
    init(id: Identifier<Train>) {
        self.id = id
    }

}

extension Train: Codable {
    
    enum CodingKeys: CodingKey {
      case id, enabled, name, iconUrlData, address, speed, decoder, direction, route, routeIndex, block, position, trailingBlocks, maxLeadingBlocks
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try container.decode(Identifier<Train>.self, forKey: CodingKeys.id))
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.enabled) ?? true
        self.name = try container.decode(String.self, forKey: CodingKeys.name)
        self.iconUrlData = try container.decodeIfPresent(Data.self, forKey: CodingKeys.iconUrlData)
        self.address = try container.decode(UInt32.self, forKey: CodingKeys.address)
        self.decoder = try container.decode(DecoderType.self, forKey: CodingKeys.decoder)
        self.speed = try container.decode(TrainSpeed.self, forKey: CodingKeys.speed)
        self.speed.kph = 0 // Always reset with speed to 0 when restoring from disk
        self.directionForward = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.direction) ?? true
        self.routeId = try container.decodeIfPresent(Identifier<Route>.self, forKey: CodingKeys.route)
        self.routeStepIndex = try container.decode(Int.self, forKey: CodingKeys.routeIndex)
        self.blockId = try container.decodeIfPresent(Identifier<Block>.self, forKey: CodingKeys.block)
        self.position = try container.decode(Int.self, forKey: CodingKeys.position)
        self.numberOfTrailingReservedBlocks = try container.decodeIfPresent(Int.self, forKey: CodingKeys.trailingBlocks) ?? 0
        self.maxNumberOfLeadingReservedBlocks = try container.decodeIfPresent(Int.self, forKey: CodingKeys.maxLeadingBlocks) ?? 1
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(enabled, forKey: CodingKeys.enabled)
        try container.encode(name, forKey: CodingKeys.name)
        try container.encode(iconUrlData, forKey: CodingKeys.iconUrlData)
        try container.encode(address, forKey: CodingKeys.address)
        try container.encode(decoder, forKey: CodingKeys.decoder)
        try container.encode(speed, forKey: CodingKeys.speed)
        try container.encode(directionForward, forKey: CodingKeys.direction)
        try container.encode(routeId, forKey: CodingKeys.route)
        try container.encode(routeStepIndex, forKey: CodingKeys.routeIndex)
        try container.encode(blockId, forKey: CodingKeys.block)
        try container.encode(position, forKey: CodingKeys.position)
        try container.encode(numberOfTrailingReservedBlocks, forKey: CodingKeys.trailingBlocks)
        try container.encode(maxNumberOfLeadingReservedBlocks, forKey: CodingKeys.maxLeadingBlocks)
    }

}

extension Array where Element : Train {

    func find(address: UInt32, decoder: DecoderType?) -> Element? {
        return self.first { train in
            return train.address.actualAddress(for: train.decoder) == address.actualAddress(for: decoder)
        }
    }
    
}