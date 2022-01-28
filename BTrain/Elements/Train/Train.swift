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
// A train consists of a locomotive and zero, one or more wagons.
// From a geometry point of view, these are the measurements needed:
//
//
//      │◀─────────────────────Train Length──────────────────────▶│
//      │                                                         │
//  B   │                                                         │   F
//  a   │                                                         │   r
//  c   ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   o
//  k   │                 │ │                 │ │                 │   n
//      │      wagon      │ │      wagon      │ │   locomotive    │   t
//      │                 │ │                 │ │      ▨          │
//      └─────────────────┘ └─────────────────┘ └──────┬──────────┘
//                                                     │          │
//                                                     │          │
//                                                     │          │
//                                                     │ ◀────────│
//
//                                                    Magnet Distance
//
final class Train: Element, ObservableObject {
    // Unique identifier of the train
    let id: Identifier<Train>
    
    // A train that is enabled will show up in the switchboard
    @Published var enabled = true
    
    // Name of the train
    @Published var name = ""
        
    // Address of the train
    @Published var address: UInt32 = 0
      
    // The decoder type of this train
    @Published var decoder: DecoderType = .MFX {
        didSet {
            speed.decoderType = decoder
        }
    }
    
    // Length of the train (in cm)
    @Published var length: Double?

    // Distance of the magnet from the front of the train (in cm)
    // BTrain expects all the train (locomotive) to have a magnet
    // to allow detection via reed feedback.
    @Published var magnetDistance: Double?

    // Speed of the train
    @Published var speed = TrainSpeed(kph: 0, decoderType: .MFX)

    // Direction of travel of the train
    @Published var directionForward = true
    
    // The route this train is associated with
    @Published var routeId: Identifier<Route>?
    
    // Index of the current route step that the train is located in.
    @Published var routeStepIndex = 0
        
    // The maximum number of blocks that should be reserved ahead of the train.
    // The actual number of blocks might be smaller if a block cannot be reserved.
    // The default is 1.
    @Published var maxNumberOfLeadingReservedBlocks = 1
    
    enum Schedule {
        // The train is stopped and cannot be started again
        // unless the user takes an explicit action (ie Start button)
        case manual
        
        // The train is running and has not yet finished the route
        // Note: a train can be "stopped" with a speed of 0 kph while still
        // be in a running state. This happens when the train stops because
        // the next block is occupied or it has reached a station.
        // If `finishing` is set to true, the train will stop when it finishes the route.
        case automatic(finishing: Bool)
    }
    
    // The state of the schedule
    @Published var scheduling: Schedule = .manual
    
    var manualScheduling: Bool {
        if case .manual = scheduling {
            return true
        } else {
            return false
        }
    }
    
    var automaticFinishingScheduling: Bool {
        if case .automatic(let finishing) = scheduling {
            return finishing
        } else {
            return false
        }
    }

    var automaticScheduling: Bool {
        if case .automatic(_) = scheduling {
            return true
        } else {
            return false
        }
    }

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
    
    struct BlockItem: Identifiable, Codable, Hashable {
        let id: String
        
        var blockId: Identifier<Block>
        
        init(_ blockId: Identifier<Block>) {
            self.id = UUID().uuidString
            self.blockId = blockId
        }
    }
    
    // List of blocks to avoid. For example, specific blocks
    // should be avoided for Intercity train because their
    // radius is too small and causes derailing.
    @Published var blocksToAvoid = [BlockItem]()
    
    // The time remaining until the train is automatically restarted
    // Note: we don't need to store this property because it is used only
    // when running the layout.
    var timeUntilAutomaticRestart: TimeInterval = 0

    var description: String {
        return "\(name) (\(id))"
    }
    
    convenience init(uuid: String = UUID().uuidString, name: String = "", address: UInt32 = 0, decoder: DecoderType = .MFX,
                     length: Double? = nil, magnetDistance: Double? = nil, maxSpeed: TrainSpeed.UnitKph? = nil, maxNumberOfLeadingReservedBlocks: Int? = nil) {
        self.init(id: Identifier(uuid: uuid), name: name, address: address, decoder: decoder)
    }
    
    init(id: Identifier<Train>, name: String, address: UInt32, decoder: DecoderType = .MFX,
         length: Double? = nil, magnetDistance: Double? = nil, maxSpeed: TrainSpeed.UnitKph? = nil, maxNumberOfLeadingReservedBlocks: Int? = nil) {
        self.id = id
        self.name = name
        self.address = address
        self.length = length
        self.magnetDistance = magnetDistance
        self.speed.maxSpeed = maxSpeed ?? self.speed.maxSpeed
        self.maxNumberOfLeadingReservedBlocks = maxNumberOfLeadingReservedBlocks ?? self.maxNumberOfLeadingReservedBlocks
    }
}

extension Train: Codable {
    
    enum CodingKeys: CodingKey {
      case id, enabled, name, address, length, magnetDistance, speed, decoder, direction, route, routeIndex, block, position, maxLeadingBlocks, blocksToAvoid
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(Identifier<Train>.self, forKey: CodingKeys.id)
        let name = try container.decode(String.self, forKey: CodingKeys.name)
        let address = try container.decode(UInt32.self, forKey: CodingKeys.address)

        self.init(id: id, name: name, address: address)
        
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.enabled) ?? true
        self.decoder = try container.decode(DecoderType.self, forKey: CodingKeys.decoder)
        self.length = try container.decodeIfPresent(Double.self, forKey: CodingKeys.length)
        self.magnetDistance = try container.decodeIfPresent(Double.self, forKey: CodingKeys.magnetDistance)
        self.speed = try container.decode(TrainSpeed.self, forKey: CodingKeys.speed)
        self.speed.kph = 0 // Always reset with speed to 0 when restoring from disk
        self.directionForward = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.direction) ?? true
        self.routeId = try container.decodeIfPresent(Identifier<Route>.self, forKey: CodingKeys.route)
        self.routeStepIndex = try container.decode(Int.self, forKey: CodingKeys.routeIndex)
        self.blockId = try container.decodeIfPresent(Identifier<Block>.self, forKey: CodingKeys.block)
        self.position = try container.decode(Int.self, forKey: CodingKeys.position)
        self.maxNumberOfLeadingReservedBlocks = try container.decodeIfPresent(Int.self, forKey: CodingKeys.maxLeadingBlocks) ?? 1
        self.blocksToAvoid = try container.decodeIfPresent([BlockItem].self, forKey: CodingKeys.blocksToAvoid) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(enabled, forKey: CodingKeys.enabled)
        try container.encode(name, forKey: CodingKeys.name)
        try container.encode(address, forKey: CodingKeys.address)
        try container.encode(decoder, forKey: CodingKeys.decoder)
        try container.encode(length, forKey: CodingKeys.length)
        try container.encode(magnetDistance, forKey: CodingKeys.magnetDistance)
        try container.encode(speed, forKey: CodingKeys.speed)
        try container.encode(directionForward, forKey: CodingKeys.direction)
        try container.encode(routeId, forKey: CodingKeys.route)
        try container.encode(routeStepIndex, forKey: CodingKeys.routeIndex)
        try container.encode(blockId, forKey: CodingKeys.block)
        try container.encode(position, forKey: CodingKeys.position)
        try container.encode(maxNumberOfLeadingReservedBlocks, forKey: CodingKeys.maxLeadingBlocks)
        try container.encode(blocksToAvoid, forKey: CodingKeys.blocksToAvoid)
    }

}

extension Array where Element : Train {

    func find(address: UInt32, decoder: DecoderType?) -> Element? {
        return self.first { train in
            return train.address.actualAddress(for: train.decoder) == address.actualAddress(for: decoder)
        }
    }
    
}
