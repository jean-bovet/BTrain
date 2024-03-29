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

/// A train consists of a locomotive and zero, one or more wagons.
///
/// A train moves forward and, optionally, backward.
/// - When moving forward, BTrain relies on the feedback at the head of the train to know where the train is located.
/// - When moving backward, BTrain relies on the feedback at the tail of the train to know where the train is located. If there is
/// no feedback at the tail of the train, BTrain uses the head feedback to estimate the tail position of the train.
///
/// Definitions:
/// - Head: the portion of the train where the locomotive is located.
/// - Tail: the portion of the train at the opposite end of the locomotive.
///
/// Limitations:
/// - BTrain does not support locomotive at the tail of the train.
/// - BTrain does not yet support computing real-time distance estimation of the train.
///
///                                                                                     locomotive
///                                                                                     │
///                                                                                     │
///                            ◀─────────────────────────cars──────────────────────────▶▼
///                      Tail ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■▶ Head
///                            ┌─▶▼                                                 ▼◀─┐
///              Tail Position─┘                                                       └──Head Position
final class Train: Element, ObservableObject {
    /// Unique identifier of the train
    let id: Identifier<Train>

    /// A train that is enabled will show up in the switchboard
    @Published var enabled = true

    /// Name of the train
    @Published var name = ""

    /// The locomotive assigned to this train
    @ElementProperty var locomotive: Locomotive?

    /// Length of the wagons (in cm)
    @Published var wagonsLength: DistanceCm?

    /// The route associated with this train
    @Published var routeId: Identifier<Route>

    /// Keeping track of the route index when the train starts,
    /// to avoid stopping it immediately if it is still starting
    /// in the first block of the route.
    @Published var startRouteIndex: Int?

    /// Index of the current route step that the train is located in.
    @Published var routeStepIndex = 0

    /// The maximum number of blocks that should be reserved ahead of the train.
    /// The actual number of blocks might be smaller if a block cannot be reserved.
    /// The default is 2.
    @Published var maxNumberOfLeadingReservedBlocks = 2

    struct Reservation {
        /// Keeps track of the leading reservation, blocks or turnouts, that are assigned to this train.
        let leading = TrainLeadingReservation()

        /// Keeps track of the blocks and turnouts occupied by this train.
        let occupied = TrainOccupiedReservation()

        /// Specify the next block in which the train will enter, given its position and direction of travel.
        /// Note: during automated routing (automatic or fixed), this variable correspond to the first
        /// leading block. During manual operation, the leading blocks are empty but this variable is used
        /// to properly move the train to the next block.
        var nextBlock: Block?
    }

    /// The block reservation, available at runtime only (never persisted).
    var reservation = Reservation()

    /// Schedule state of the train
    enum Schedule {
        /// The train is monitored by BTrain but not managed. This mode is used when the user wants to drive the train on its own via
        /// the digital controller. In this mode, BTrain will monitor the movement of the train to detect its location on the layout and
        /// stop it in case of collision.
        case unmanaged

        /// The train is managed by BTrain. This mode is used when BTrain is driving the train using either a fixed or automatic route.
        case managed

        /// Request to stop the train as soon as possible and go to unmanaged mode
        case stopManaged

        /// Request to stop the train immediately and go to unmanaged mode
        case stopImmediatelyManaged

        /// Request to stop the train at the next station and go to unmanaged mode
        case finishManaged
    }

    /// The state of the schedule
    @Published var scheduling: Schedule = .unmanaged

    enum State {
        case running
        case braking
        case stopping
        case stopped
    }

    /// The state of the train
    @Published var state: State = .stopped

    /// The positions of the train
    @Published var positions = TrainPositions()

    /// True if the tail of the train can be detected. By default, only the head
    /// of the train is detected (that is, a sensor below the front locomotive is detected).
    /// However, to accurately drive a train moving backwards, a sensor in the last wagon
    /// should be installed and this is what this variable is about.
    @Published var isTailDetected = false

    struct BlockItem: Identifiable, Codable, Hashable {
        let id: String

        var blockId: Identifier<Block>?

        init(_ blockId: Identifier<Block>?) {
            id = UUID().uuidString
            self.blockId = blockId
        }
    }

    /// List of blocks to avoid. For example, specific blocks
    /// should be avoided for Intercity train because their
    /// radius is too small and causes derailing.
    @Published var blocksToAvoid = [BlockItem]()

    struct TurnoutItem: Identifiable, Codable, Hashable {
        let id: String

        var turnoutId: Identifier<Turnout>

        init(_ turnoutId: Identifier<Turnout>) {
            id = UUID().uuidString
            self.turnoutId = turnoutId
        }
    }

    /// List of turnouts to avoid. For example, specific turnouts
    /// should be avoided for Intercity train because their
    /// radius is too small and causes derailing.
    @Published var turnoutsToAvoid = [TurnoutItem]()

    /// The time remaining until the train is automatically restarted
    /// Note: we don't need to persist this property because it is used only
    /// when running the layout.
    var timeUntilAutomaticRestart: TimeInterval = 0

    convenience init(uuid: String = UUID().uuidString, name: String = "", wagonsLength: Double? = nil, maxSpeed: SpeedKph? = nil, maxNumberOfLeadingReservedBlocks: Int? = nil) {
        self.init(id: Identifier(uuid: uuid), name: name, wagonsLength: wagonsLength, maxSpeed: maxSpeed, maxNumberOfLeadingReservedBlocks: maxNumberOfLeadingReservedBlocks)
    }

    init(id: Identifier<Train>, name: String, wagonsLength: Double? = nil, maxSpeed _: SpeedKph? = nil, maxNumberOfLeadingReservedBlocks: Int? = nil) {
        self.id = id
        routeId = Route.automaticRouteId(for: id)
        self.name = name
        self.wagonsLength = wagonsLength
        self.maxNumberOfLeadingReservedBlocks = maxNumberOfLeadingReservedBlocks ?? self.maxNumberOfLeadingReservedBlocks
    }
}

extension Train {
    func description(_ layout: Layout) -> String {
        var text = "Train '\(name)' (\(id), \(state)"
        text += ", \(scheduling)"
        text += ", \(positions.description(layout))"
        if locomotive != nil {
            text += ", \(directionForward ? "f" : "b")"
        } else {
            text += ", ?"
        }
        if let speed = speed {
            text += ", r=\(speed.requestedKph)kph"
            text += ", a=\(speed.actualKph)kph"
        }
        text += ")"
        return text
    }
}

extension Train {
    var speed: LocomotiveSpeed? {
        locomotive?.speed
    }

    var length: Double? {
        let ll = locomotive?.length ?? 0
        let wl = wagonsLength ?? 0
        return ll + wl
    }

    var directionForward: Bool {
        assert(locomotive != nil)
        return locomotive?.directionForward ?? true
    }

    var leading: TrainLeadingReservation {
        reservation.leading
    }

    var occupied: TrainOccupiedReservation {
        reservation.occupied
    }

    /// Returns the block that is located at the front of the train.
    ///
    /// The front of the train is the portion of the train that is towards the direction of travel:
    /// - If the train moves forward, the front block is the block where the locomotive is located
    /// - If the train moves backward, the front block is the block where the last wagon is located
    var frontBlockId: Identifier<Block>? {
        frontPosition?.blockId
    }

    var frontPosition: TrainPosition? {
        guard let locomotive = locomotive else {
            return nil
        }
        if locomotive.directionForward {
            return positions.head
        } else {
            return positions.tail
        }
    }

    func locomotiveOrThrow() throws -> Locomotive {
        if let loc = locomotive {
            return loc
        } else {
            throw LayoutError.locomotiveNotAssignedToTrain(train: self)
        }
    }
}

extension Train: Restorable {
    func restore(layout: Layout) {
        _locomotive.restore(layout.locomotives)
    }
}

extension Train: Comparable {
    static func < (lhs: Train, rhs: Train) -> Bool {
        lhs.name < rhs.name
    }
}

extension Train: Codable {
    enum CodingKeys: CodingKey {
        case id, enabled, name, locomotive, wagonsLength, route, routeIndex, position, maxLeadingBlocks, blocksToAvoid, turnoutsToAvoid
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(Identifier<Train>.self, forKey: CodingKeys.id)
        let name = try container.decode(String.self, forKey: CodingKeys.name)

        self.init(id: id, name: name)

        _locomotive.elementId = try container.decodeIfPresent(Identifier<Locomotive>.self, forKey: CodingKeys.locomotive)

        enabled = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.enabled) ?? true
        wagonsLength = try container.decodeIfPresent(Double.self, forKey: CodingKeys.wagonsLength)
        routeId = try container.decodeIfPresent(Identifier<Route>.self, forKey: CodingKeys.route) ?? Route.automaticRouteId(for: id)
        routeStepIndex = try container.decode(Int.self, forKey: CodingKeys.routeIndex)
        // Note: previous version of the encoding did not include a direction with the positions
        // so if it cannot be decoded, the train is simply removed from the layout and must be
        // re-added by the user.
        if let positions = try? container.decode(TrainPositions.self, forKey: CodingKeys.position) {
            self.positions = positions
        }
        maxNumberOfLeadingReservedBlocks = try container.decodeIfPresent(Int.self, forKey: CodingKeys.maxLeadingBlocks) ?? 1
        blocksToAvoid = try container.decodeIfPresent([BlockItem].self, forKey: CodingKeys.blocksToAvoid) ?? []
        turnoutsToAvoid = try container.decodeIfPresent([TurnoutItem].self, forKey: CodingKeys.turnoutsToAvoid) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(enabled, forKey: CodingKeys.enabled)
        try container.encode(name, forKey: CodingKeys.name)
        try container.encode(_locomotive.elementId, forKey: CodingKeys.locomotive)
        try container.encode(wagonsLength, forKey: CodingKeys.wagonsLength)
        try container.encode(routeId, forKey: CodingKeys.route)
        try container.encode(routeStepIndex, forKey: CodingKeys.routeIndex)
        try container.encode(positions, forKey: CodingKeys.position)
        try container.encode(maxNumberOfLeadingReservedBlocks, forKey: CodingKeys.maxLeadingBlocks)
        try container.encode(blocksToAvoid, forKey: CodingKeys.blocksToAvoid)
        try container.encode(turnoutsToAvoid, forKey: CodingKeys.turnoutsToAvoid)
    }
}
