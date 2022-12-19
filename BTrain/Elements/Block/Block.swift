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

/// A block is a section of track between two turnouts or another block.
///
/// A block consists of the following elements:
/// - Socket: each block has two sockets, one at the beginning (0) and one at the end (1)
/// - Block Direction: each block has a natural direction that flows from socket 0 to socket 1.
/// - Train: each block has a reference to the train located in that block, including its direction
/// of travel which can be either in the block direction (next) or in the opposite direction (previous).
/// - Feedback: each block has at least one feedback to help determine if a train is located in that block.
/// Ideally two feedbacks are used to determine when the train enters or exists the block with more precision.
/// The feedbacks indexes go from 0 to n following the block natural direction./
/// ```
///                  Feedback                       Block Direction
///  p                  │                                  │
///  r     Socket       │                  Train           │
///  e       │          │                    │             │           n
///  v       │          │                    │             │           e
///  i       │          │                    │             │           x
///  o       │          ▼                    │             ▼           t
///  u       │  ╲       ██            ██     │      ██    ╲
///  s       ▼   ╲      ██            ██     ▼      ██     ╲           s
///        ──○────■─────██────────────██─────■■▶────██──────■────○──   i
///  s       0   ╱      ██            ██            ██     ╱     1     d
///  i          ╱       ██            ██            ██    ╱            e
///  d
///  e                  f0            f1            f2
///
///       ─────────────────────────────────────────────────────────▶
///                              block natural direction
/// ```
/// In terms of geometry, the block needs the following measurements:
/// - Block length
/// - Distance of each feedback from the start of the block
/// ```
///      │◀──────────────────Block Length───────────────▶│
///      │                                               │
///      │     ██            ██            ██            │  F
///  B   │     ██            ██            ██            │  r
///  a   ──────██────────────██────────────██────────────■  o
///  c   │     ██            ██            ██               n
///  k   │     ██            ██            ██               t
///      │                    │
///      │                    │
///      │       Feedback     │
///      │ ──────Distance────▶│
/// ```
final class Block: Element, ObservableObject {
    /// The category of the block
    enum Category: String, Codable, CaseIterable {
        /// A station block where the train stops
        case station

        /// A free section of track
        case free

        /// A siding (a block that ends at one end) in the previous direction
        case sidingPrevious

        /// A siding (a block that ends at one end) in the next direction
        case sidingNext
    }

    /// The unique identifier of the block
    let id: Identifier<Block>

    /// True if the block is enabled and ready to participate
    /// in the routing. False to have the block ignored
    /// by any routing, which is useful when a block is occupied
    /// or in need of repair and we don't want to have a train
    /// stopping or running through it.
    @Published var enabled = true

    /// The name of the block
    @Published var name: String

    /// The category of the block
    @Published var category: Category = .free

    /// Length of the block (in cm)
    @Published var length: Double?

    /// The number of seconds a train will wait in that block before starting again.
    ///
    /// This value is used only in automatic routes.
    @Published var waitingTime: TimeInterval = 10.0

    /// The center of the block in the switchboard
    var center: CGPoint = .zero

    /// Rotation angle of the block, in radian of the block in the switchboard
    var rotationAngle: CGFloat = 0

    /// Holds a reservation for a particular train.
    ///
    /// Note that a reserved block does not necessarily have
    /// a train in it: this is indicated by the ``train`` property.
    @Published var reservation: Reservation?

    /// Returns the current train (and its direction of travel) inside this block
    @Published var trainInstance: TrainInstance?

    /// Returns true if this block contains the locomotive
    var blockContainsLocomotive: Bool {
        guard let trainInstance = trainInstance else {
            return false
        }

        if trainInstance.parts.isEmpty {
            // If there are no parts defined, it means the train has not length defined,
            // so we can consider the entire block as containing the locomotive
            return true
        } else {
            return trainInstance.parts.values.contains(.locomotive)
        }
    }

    /// A structure identifying each feedback inside this block
    struct BlockFeedback: Identifiable, Hashable, Codable {
        /// Unique identifier for this block feedback
        let id: String

        /// The feedback identifier this block feedback refers to
        var feedbackId: Identifier<Feedback>

        /// Distance, in cm, of the feedback from the start of the block
        var distance: Double?
    }

    /// Array of feedbacks in this block
    @Published var feedbacks = [BlockFeedback]()

    /// The optional feedback designated as the entry feedback in the direction next
    @Published var entryFeedbackNext: Identifier<Feedback>?

    /// The optional feedback designated as the braking feedback in the direction next
    @Published var brakeFeedbackNext: Identifier<Feedback>?

    /// The optional feedback designated as the stop feedback in the direction next
    @Published var stopFeedbackNext: Identifier<Feedback>?

    /// The optional feedback designated as the entry feedback in the direction previous
    @Published var entryFeedbackPrevious: Identifier<Feedback>?

    /// The optional feedback designated as the braking feedback in the direction previous
    @Published var brakeFeedbackPrevious: Identifier<Feedback>?

    /// The optional feedback designated as the stop feedback in the direction previous
    @Published var stopFeedbackPrevious: Identifier<Feedback>?

    /// Optional block-specific braking speed.
    ///
    /// If nil, the default braking speed is used
    @Published var brakingSpeed: SpeedKph?

    /// The possible speed limits
    enum SpeedLimit: String, Codable, CaseIterable {
        /// Unlimited speed - the block does not put any speed constraints
        case unlimited

        /// Limited speed - the block has a limit on the possible speed value
        case limited
    }

    /// Speed limit for this block, defaults to unlimited
    @Published var speedLimit: SpeedLimit = .unlimited

    init(id: Identifier<Block>, name: String = "") {
        self.id = id
        self.name = name
    }

    convenience init(name: String = UUID().uuidString) {
        self.init(id: Identifier<Block>(uuid: name), name: name)
    }

    func description(_ layout: Layout) -> String {
        var info = "\(name)-[\(id)]"
        if let reserved = reservation, let train = layout.trains[reserved.trainId] {
            info += ", reserved for '\(train.name)'-\(reserved.direction)"
        }
        if let trainInstance = trainInstance {
            if let train = layout.trains[trainInstance.trainId] {
                info += ", \(train.description(layout))"
            }
            if trainInstance.direction == .next {
                info += ", direction forward"
            } else {
                info += ", direction backward"
            }
        }
        return info
    }
}

extension Block: Restorable {
    func restore(layout _: Layout) {
        if trainInstance == nil {
            // Do not restore the reservation if the train does not belong to this block.
            // We do not want the user to see reservation upon opening a new document because
            // the train is not actively running anymore.
            reservation = nil
        }
    }
}

extension Block: Codable {
    enum CodingKeys: CodingKey {
        case id, enabled, name, type, length, waitingTime, reserved, train, feedbacks,
             entryFeedbackNext, brakeFeedbackNext, stopFeedbackNext,
             entryFeedbackPrevious, brakeFeedbackPrevious, stopFeedbackPrevious,
             brakingSpeed, speedLimit,
             center, angle
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(Identifier<Block>.self, forKey: CodingKeys.id)
        let name = try container.decode(String.self, forKey: CodingKeys.name)

        self.init(id: id, name: name)

        category = try container.decode(Category.self, forKey: CodingKeys.type)
        center = try container.decode(CGPoint.self, forKey: CodingKeys.center)
        rotationAngle = try container.decode(Double.self, forKey: CodingKeys.angle)
        waitingTime = try container.decode(TimeInterval.self, forKey: CodingKeys.waitingTime)
        length = try container.decodeIfPresent(Double.self, forKey: CodingKeys.length)

        enabled = try container.decode(Bool.self, forKey: CodingKeys.enabled)
        reservation = try container.decodeIfPresent(Reservation.self, forKey: CodingKeys.reserved)
        trainInstance = try container.decodeIfPresent(TrainInstance.self, forKey: CodingKeys.train)
        feedbacks = try container.decode([BlockFeedback].self, forKey: CodingKeys.feedbacks)

        entryFeedbackNext = try container.decodeIfPresent(Identifier<Feedback>.self, forKey: CodingKeys.entryFeedbackNext)
        brakeFeedbackNext = try container.decodeIfPresent(Identifier<Feedback>.self, forKey: CodingKeys.brakeFeedbackNext)
        stopFeedbackNext = try container.decodeIfPresent(Identifier<Feedback>.self, forKey: CodingKeys.stopFeedbackNext)

        entryFeedbackPrevious = try container.decodeIfPresent(Identifier<Feedback>.self, forKey: CodingKeys.entryFeedbackPrevious)
        brakeFeedbackPrevious = try container.decodeIfPresent(Identifier<Feedback>.self, forKey: CodingKeys.brakeFeedbackPrevious)
        stopFeedbackPrevious = try container.decodeIfPresent(Identifier<Feedback>.self, forKey: CodingKeys.stopFeedbackPrevious)

        brakingSpeed = try container.decodeIfPresent(SpeedKph.self, forKey: CodingKeys.brakingSpeed)
        speedLimit = try container.decode(SpeedLimit.self, forKey: CodingKeys.speedLimit)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(enabled, forKey: CodingKeys.enabled)
        try container.encode(name, forKey: CodingKeys.name)
        try container.encode(category, forKey: CodingKeys.type)
        try container.encode(length, forKey: CodingKeys.length)
        try container.encode(waitingTime, forKey: CodingKeys.waitingTime)
        try container.encode(reservation, forKey: CodingKeys.reserved)
        try container.encode(trainInstance, forKey: CodingKeys.train)
        try container.encode(feedbacks, forKey: CodingKeys.feedbacks)

        try container.encode(entryFeedbackNext, forKey: CodingKeys.entryFeedbackNext)
        try container.encode(brakeFeedbackNext, forKey: CodingKeys.brakeFeedbackNext)
        try container.encode(stopFeedbackNext, forKey: CodingKeys.stopFeedbackNext)

        try container.encode(entryFeedbackPrevious, forKey: CodingKeys.entryFeedbackPrevious)
        try container.encode(brakeFeedbackPrevious, forKey: CodingKeys.brakeFeedbackPrevious)
        try container.encode(stopFeedbackPrevious, forKey: CodingKeys.stopFeedbackPrevious)

        try container.encode(brakingSpeed, forKey: CodingKeys.brakingSpeed)
        try container.encode(speedLimit, forKey: CodingKeys.speedLimit)

        try container.encode(center, forKey: CodingKeys.center)
        try container.encode(rotationAngle, forKey: CodingKeys.angle)
    }
}

extension Block.Category: CustomStringConvertible {
    var description: String {
        switch self {
        case .station:
            return "Station"
        case .free:
            return "Free Track"
        case .sidingPrevious:
            return "Siding (stop in previous direction)"
        case .sidingNext:
            return "Siding (stop in next direction)"
        }
    }
}
