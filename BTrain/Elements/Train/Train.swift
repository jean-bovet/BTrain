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
// ================ Train Direction Discussion =========================
//
// Axioms:
// - A locomotive can move forward or backward
// - The train direction within a block is determined by the locomotive direction
//   and the side by which the train enters a new block.
// - The wagons direction can only be changed by manual input from the user because
//   they should not change (once a train is on the layout, the wagons are always oriented
//   "behind" the locomotive, regardless of the direction of motion of the locomotive).
// Let's look at some scenarios:
//                  ▷             ◁             ◁
//             ┌─────────┐   ┌─────────┐   ┌─────────┐
//             │ ■■■■■■▶ │──▶│ ■■■■■■▶ │──▶│ ■■■■■■▶ │
//             └─────────┘   └─────────┘   └─────────┘
//    LOC:     forward       forward       forward
//    DIB:     next          previous      previous
//    WAG:     previous      next          next
//
//                  ▷             ◁             ◁
//             ┌─────────┐   ┌─────────┐   ┌─────────┐
//             │ ■■■■■■◀ │◀──│ ■■■■■■◀ │◀──│ ■■■■■■◀ │
//             └─────────┘   └─────────┘   └─────────┘
//    LOC:     backward      backward      backward
//    DIB:     previous      next          next
//    WAG:     previous      next          next
//
//                  ▷             ◁             ◁
//             ┌─────────┐   ┌─────────┐   ┌─────────┐
//             │ ▶■■■■■■ │──▶│ ▶■■■■■■ │──▶│ ▶■■■■■■ │
//             └─────────┘   └─────────┘   └─────────┘
//    LOC:     backward      backward      backward
//    DIB:     next          previous      previous
//    WAG:     next          previous      previous
//
//                  ▷             ◁             ◁
//             ┌─────────┐   ┌─────────┐   ┌─────────┐
//             │ ◀■■■■■■ │◀──│ ◀■■■■■■ │◀──│ ◀■■■■■■ │
//             └─────────┘   └─────────┘   └─────────┘
//    LOC:     forward       forward       forward
//    DIB:     previous      next          next
//    WAG:     next          previous      previous
//
// Legends:
// LOC: Locomotive direction of travel (forward or backward)
// DIB: Direction of the train relative to the block natural direction
// WAG: Direction of the wagons relative to the block natural direction
// ▷: Orientation of the block (natural direction)
// ◀: Locomotive
// ■: Wagon
// ──▶: Direction in which the train is moving from one block to another
final class Train: Element, ObservableObject {
    // Unique identifier of the train
    let id: Identifier<Train>
    
    // A train that is enabled will show up in the switchboard
    @Published var enabled = true
    
    // Name of the train
    @Published var name = ""
    
    // Runtime-information only. This is not stored and is only
    // used to display transient information when the train
    // is running in the layout.
    @Published var runtimeInfo: String?
    
    // Address of the train
    @Published var address: UInt32 = 0
      
    // The decoder type of this train
    @Published var decoder: DecoderType = .MFX {
        didSet {
            speed.decoderType = decoder
        }
    }
    
    // Length of the locomotive (in cm)
    @Published var locomotiveLength: Double?
    
    // Length of the wagons (in cm)
    @Published var wagonsLength: Double?

    var length: Double? {
        if let locomotiveLength = locomotiveLength {
            if let wagonsLength = wagonsLength {
                return locomotiveLength + wagonsLength
            } else {
                return locomotiveLength
            }
        } else {
            return nil
        }
    }
    
    // Distance of the magnet from the front of the locomotive (in cm)
    // BTrain expects all the locomotives to have a magnet
    // to allow detection via a reed feedback.
    // TODO: use this in distance calculation?
    @Published var magnetDistance: Double?

    // Speed of the locomotive
    @Published var speed = TrainSpeed(kph: 0, decoderType: .MFX)

    // Direction of travel of the locomotive
    @Published var directionForward = true

    // Indicates if the wagons are pushed or pulled by the locomotive.
    // It is used to correctly reserve the blocks occupied by the length of the train
    // when the train length is larger than the block it occupies.
    @Published var wagonsPushedByLocomotive = false
    
    // The route this train is associated with
    @Published var routeId: Identifier<Route>?
    
    // Keeping track of the route index when the train starts,
    // to avoid stopping it immediately if it is still starting
    // in the first block of the route.
    @Published var startRouteIndex: Int?

    // Index of the current route step that the train is located in.
    @Published var routeStepIndex = 0
        
    // The maximum number of blocks that should be reserved ahead of the train.
    // The actual number of blocks might be smaller if a block cannot be reserved.
    // The default is 2.
    @Published var maxNumberOfLeadingReservedBlocks = 2
    
    /// Array of leading blocks that have been reserved in front of the train.
    ///
    /// This array is updated by the ``LayoutReservation`` class each time the reserved
    /// blocks are updated. The leading blocks are stored here for quick access instead
    /// of re-computing them on the fly all the time.
    var leadingBlocks = [Block]()
    
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
        case stopping
        case stopped
    }
    
    // The state of the train
    @Published var state: State = .stopped
    
    /// Enumartion that indicates a request to change the state of train, like starting or stopping the train.
    enum StateChangeRequest: CustomStringConvertible, Equatable {

        /// The train is requested to start
        case start
        
        /// The train will be fully stopped and the scheduling placed back to ``Train/Schedule/manual``.
        case stopCompletely
        
        /// The train will stop and be restarted after the specified delay
        case stopAndRestart(delay: TimeInterval)
        
        /// The train will stop temporarily and restart as soon as the leading blocks can be reserved again
        case stopTemporarily
        
        var description: String {
            switch self {
            case .start:
                return "start"
            case .stopCompletely:
                return "stopCompletely"
            case .stopAndRestart(delay: let delay):
                return "stopAndRestart(after: \(delay))"
            case .stopTemporarily:
                return "stopTemporarily"
            }
        }

        static func ==(lhs: StateChangeRequest, rhs: StateChangeRequest) -> Bool {
            switch (lhs, rhs) {
            case (.start, .start):
                return true
            case (.stopCompletely, .stopCompletely):
                return true
            case (.stopAndRestart(delay: let d1), .stopAndRestart(delay: let d2)):
                return d1 == d2
            case (.stopTemporarily, .stopTemporarily):
                return true
            default:
                return false
            }
        }
    }
            
    /// If not nil, this variable indicates a request to change the state of the train
    @Published var stateChangeRequest: StateChangeRequest? = nil
        
    // The block where the locomotive is located
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

    struct TurnoutItem: Identifiable, Codable, Hashable {
        let id: String
        
        var turnoutId: Identifier<Turnout>
        
        init(_ turnoutId: Identifier<Turnout>) {
            self.id = UUID().uuidString
            self.turnoutId = turnoutId
        }
    }

    // List of turnouts to avoid. For example, specific turnouts
    // should be avoided for Intercity train because their
    // radius is too small and causes derailing.
    @Published var turnoutsToAvoid = [TurnoutItem]()

    // The time remaining until the train is automatically restarted
    // Note: we don't need to store this property because it is used only
    // when running the layout.
    var timeUntilAutomaticRestart: TimeInterval = 0

    var description: String {
        var text = "Train '\(name)' (id=\(id), \(state)"
        if let stateChangeRequest = stateChangeRequest {
            text += ", \(stateChangeRequest)"
        }
        text += ", \(speed.actualKph)kph)"
        return text
    }
    
    convenience init(uuid: String = UUID().uuidString, name: String = "", address: UInt32 = 0, decoder: DecoderType = .MFX,
                     locomotiveLength: Double? = nil, wagonsLength: Double? = nil, magnetDistance: Double? = nil, maxSpeed: TrainSpeed.UnitKph? = nil, maxNumberOfLeadingReservedBlocks: Int? = nil) {
        self.init(id: Identifier(uuid: uuid), name: name, address: address, decoder: decoder,
                  locomotiveLength: locomotiveLength, wagonsLength: wagonsLength, magnetDistance: magnetDistance, maxSpeed: maxSpeed, maxNumberOfLeadingReservedBlocks: maxNumberOfLeadingReservedBlocks)
    }
    
    init(id: Identifier<Train>, name: String, address: UInt32, decoder: DecoderType = .MFX,
         locomotiveLength: Double? = nil, wagonsLength: Double? = nil, magnetDistance: Double? = nil, maxSpeed: TrainSpeed.UnitKph? = nil, maxNumberOfLeadingReservedBlocks: Int? = nil) {
        self.id = id
        self.name = name
        self.address = address
        self.locomotiveLength = locomotiveLength
        self.wagonsLength = wagonsLength
        self.magnetDistance = magnetDistance
        self.speed.maxSpeed = maxSpeed ?? self.speed.maxSpeed
        self.maxNumberOfLeadingReservedBlocks = maxNumberOfLeadingReservedBlocks ?? self.maxNumberOfLeadingReservedBlocks
    }
}

extension Train: Codable {
    
    enum CodingKeys: CodingKey {
      case id, enabled, name, address, locomotiveLength, wagonsLength, magnetDistance, speed, acceleration, stopSettleDelay, decoder, direction, wagonsPushedByLocomotive, route, routeIndex, block, position, maxLeadingBlocks, blocksToAvoid, turnoutsToAvoid
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(Identifier<Train>.self, forKey: CodingKeys.id)
        let name = try container.decode(String.self, forKey: CodingKeys.name)
        let address = try container.decode(UInt32.self, forKey: CodingKeys.address)

        self.init(id: id, name: name, address: address)
        
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.enabled) ?? true
        self.decoder = try container.decode(DecoderType.self, forKey: CodingKeys.decoder)
        self.locomotiveLength = try container.decodeIfPresent(Double.self, forKey: CodingKeys.locomotiveLength)
        self.wagonsLength = try container.decodeIfPresent(Double.self, forKey: CodingKeys.wagonsLength)
        self.magnetDistance = try container.decodeIfPresent(Double.self, forKey: CodingKeys.magnetDistance)
        self.speed = try container.decode(TrainSpeed.self, forKey: CodingKeys.speed)
        self.directionForward = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.direction) ?? true
        self.wagonsPushedByLocomotive = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.wagonsPushedByLocomotive) ?? false
        self.routeId = try container.decodeIfPresent(Identifier<Route>.self, forKey: CodingKeys.route)
        self.routeStepIndex = try container.decode(Int.self, forKey: CodingKeys.routeIndex)
        self.blockId = try container.decodeIfPresent(Identifier<Block>.self, forKey: CodingKeys.block)
        self.position = try container.decode(Int.self, forKey: CodingKeys.position)
        self.maxNumberOfLeadingReservedBlocks = try container.decodeIfPresent(Int.self, forKey: CodingKeys.maxLeadingBlocks) ?? 1
        self.blocksToAvoid = try container.decodeIfPresent([BlockItem].self, forKey: CodingKeys.blocksToAvoid) ?? []
        self.turnoutsToAvoid = try container.decodeIfPresent([TurnoutItem].self, forKey: CodingKeys.turnoutsToAvoid) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(enabled, forKey: CodingKeys.enabled)
        try container.encode(name, forKey: CodingKeys.name)
        try container.encode(address, forKey: CodingKeys.address)
        try container.encode(decoder, forKey: CodingKeys.decoder)
        try container.encode(wagonsLength, forKey: CodingKeys.wagonsLength)
        try container.encode(locomotiveLength, forKey: CodingKeys.locomotiveLength)
        try container.encode(magnetDistance, forKey: CodingKeys.magnetDistance)
        try container.encode(speed, forKey: CodingKeys.speed)
        try container.encode(directionForward, forKey: CodingKeys.direction)
        try container.encode(wagonsPushedByLocomotive, forKey: CodingKeys.wagonsPushedByLocomotive)
        try container.encode(routeId, forKey: CodingKeys.route)
        try container.encode(routeStepIndex, forKey: CodingKeys.routeIndex)
        try container.encode(blockId, forKey: CodingKeys.block)
        try container.encode(position, forKey: CodingKeys.position)
        try container.encode(maxNumberOfLeadingReservedBlocks, forKey: CodingKeys.maxLeadingBlocks)
        try container.encode(blocksToAvoid, forKey: CodingKeys.blocksToAvoid)
        try container.encode(turnoutsToAvoid, forKey: CodingKeys.turnoutsToAvoid)
    }

}

extension Array where Element : Train {

    func find(address: UInt32, decoder: DecoderType?) -> Element? {
        return self.first { train in
            return train.address.actualAddress(for: train.decoder) == address.actualAddress(for: decoder)
        }
    }
    
}
