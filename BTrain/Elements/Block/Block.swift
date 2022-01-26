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

// A block is a section of track between two turnouts or another block.
// A block consists of the following elements:
// - Socket: each block has two sockets, one at the beginning (0) and one at the end (1)
// - Block Direction: each block has a natural direction that flows from socket 0 to socket 1.
// - Train: each block has a reference to the train located in that block, including its direction
// of travel which can be either in the block direction (next) or in the opposite direction (previous).
// - Feedback: each block has at least one feedback to help determine if a train is located in that block.
// Ideally two feedbacks are used to determine when the train enters or exists the block with more precision.
// The feedbacks indexes go from 0 to n following the block natural direction.
//
//                  Feedback                       Block Direction
//  p                  │                                  │
//  r     Socket       │                  Train           │
//  e       │          │                    │             │           n
//  v       │          │                    │             │           e
//  i       │          │                    │             │           x
//  o       │          ▼                    │             ▼           t
//  u       │  ╲       ██            ██     │      ██    ╲
//  s       ▼   ╲      ██            ██     ▼      ██     ╲           s
//        ──○────■─────██────────────██─────■■▶────██──────■────○──   i
//  s       0   ╱      ██            ██            ██     ╱     1     d
//  i          ╱       ██            ██            ██    ╱            e
//  d
//  e                  f0            f1            f2
//
//       ─────────────────────────────────────────────────────────▶
//                              block natural direction
//
// In terms of geometry, the block needs the following measurements:
// - Block length
// - Distance of each feedback from the start of the block
//
//      │◀──────────────────Block Length───────────────▶│
//      │                                               │
//      │     ██            ██            ██            │  F
//  B   │     ██            ██            ██            │  r
//  a   ──────██────────────██────────────██────────────■  o
//  c   │     ██            ██            ██               n
//  k   │     ██            ██            ██               t
//      │                    │
//      │                    │
//      │       Feedback     │
//      │ ──────Distance────▶│
//
final class Block: Element, ObservableObject {
    
    final class TrainInstance: Codable, Equatable, CustomStringConvertible {
        // Train located in the block
        let trainId: Identifier<Train>
        
        // Direction of travel of the train within the block
        let direction: Direction

        enum TrainPart: Codable {
            case locomotive
            case wagon
        }
        
        typealias TrainPartMap = [Int:TrainPart]
        
        // A map of train part that occupies the block,
        // identified by their feedback index
        var parts = TrainPartMap()
        
        // The time remaining until the train is automatically restarted
        var timeUntilAutomaticRestart: TimeInterval = 0

        var description: String {
            return "TrainInstance(\(trainId), \(direction.rawValue))"
        }

        static func == (lhs: Block.TrainInstance, rhs: Block.TrainInstance) -> Bool {
            lhs.trainId == rhs.trainId && lhs.direction == rhs.direction
        }
        
        enum CodingKeys: CodingKey {
          case trainId, direction, parts
        }

        init(_ trainId: Identifier<Train>, _ direction: Direction, _ parts: TrainPartMap? = nil) {
            self.trainId = trainId
            self.direction = direction
            self.parts = parts ?? TrainPartMap()
        }
        
        convenience init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let trainId = try container.decode(Identifier<Train>.self, forKey: CodingKeys.trainId)
            let direction = try container.decode(Direction.self, forKey: CodingKeys.direction)
            let parts = try container.decodeIfPresent(TrainPartMap.self, forKey: CodingKeys.parts)
            self.init(trainId, direction, parts)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(trainId, forKey: CodingKeys.trainId)
            try container.encode(direction, forKey: CodingKeys.direction)
            try container.encode(parts, forKey: CodingKeys.parts)
        }
    }
    
    // Returns the length (in cm) of the part at the specified index,
    // starting from the beginning of the block.
    func partLenght(at index: Int) -> Double? {
        if index == feedbacks.count {
            // Last part:
            // [ p0  |   p1 |   p2 ]
            // [ <0> f1 <1> f2 <2> ]
            // |<--distance->|
            // |<--- length ------>|
            guard let length = length else {
                return nil
            }
            guard let feedbackDistance = feedbacks[index - 1].distance else {
                return nil
            }
            return length - feedbackDistance
        } else if index > 0 {
            // [ p0  |   p1 |   p2 ]
            // [ <0> f1 <1> f2 <2> ]
            // |<--distance->|
            // |<-d->|
            guard let feedback1Distance = feedbacks[index].distance else {
                return nil
            }
            guard let feedback2Distance = feedbacks[index - 1].distance else {
                return nil
            }
            return feedback1Distance - feedback2Distance
        } else if index == 0 {
            // First part:
            // [ p0  |   p1 |   p2 ]
            // [ <0> f1 <1> f2 <2> ]
            // |<-d->|
            return feedbacks[index].distance
        } else {
            // TODO: proper exception
            fatalError("Unexpected index")
        }

    }
    
    // Returns all the part lenght (in cm) for the entire block or nil
    // if one (or more) feedback distance is not defined.
    func allPartsLength() -> [Int:Double]? {
        var results = [Int:Double]()
        for index in 0...feedbacks.count {
            if let length = partLenght(at: index) {
                results[index] = length
            } else {
                return nil
            }
        }
        return results
    }
    
    // The category of the block
    enum Category: String, Codable, CaseIterable, Comparable {
        case station
        case free
        case sidingPrevious
        case sidingNext
        
        static func < (lhs: Block.Category, rhs: Block.Category) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    // The side of the block
    enum Side: String, Codable {
        case previous
        case next
    }

    // The unique identifier of the block
    let id: Identifier<Block>

    // True if the block is enabled and ready to participate
    // in the routing. False to have the block ignored
    // by any routing, which is useful when a block is occupied
    // or in need of repair and we don't want to have a train
    // stopping or running through it.
    var enabled = true
    
    // The name of the block
    @Published var name: String
    
    // The category of the block
    @Published var category: Category
    
    // Length of the block (in cm)
    @Published var length: Double?

    // The number of seconds a train will wait in that block
    @Published var waitingTime: TimeInterval = 10.0

    // Center of the block
    var center: CGPoint = .zero
    
    // Rotation angle of the block, in radian.
    var rotationAngle: CGFloat = 0

    // Indicates if that block is reserved for a particular train.
    // A reserved block does not necessarily have a train in it.
    @Published var reserved: Reservation?
    
    // Returns the current train (and its direction of travel) inside this block
    @Published var train: TrainInstance?
    
    // A structure identifying each feedback inside this block
    struct BlockFeedback: Identifiable, Hashable, Codable {
        let id: String
        var feedbackId: Identifier<Feedback>
        // Distance of the feedback from the start of the block
        var distance: Double?
    }
    
    // Returns the list of feedbacks in this block
    @Published var feedbacks = [BlockFeedback]()
                
    @Published var entryFeedbackNext: Identifier<Feedback>?
    @Published var brakeFeedbackNext: Identifier<Feedback>?
    @Published var stopFeedbackNext: Identifier<Feedback>?

    @Published var entryFeedbackPrevious: Identifier<Feedback>?
    @Published var brakeFeedbackPrevious: Identifier<Feedback>?
    @Published var stopFeedbackPrevious: Identifier<Feedback>?

    init(id: Identifier<Block>, name: String, type: Category, center: CGPoint, rotationAngle: CGFloat) {
        self.id = id
        self.name = name
        self.category = type
        self.center = center
        self.rotationAngle = rotationAngle
    }
    
    convenience init(_ uuid: String = UUID().uuidString, type: Category, center: CGPoint = .zero, rotationAngle: CGFloat = 0) {
        self.init(id: Identifier(uuid: uuid), name: uuid, type: type, center: center, rotationAngle: rotationAngle)
        
    }
        
}

extension Block: Codable {
    
    enum CodingKeys: CodingKey {
        case id, enabled, name, type, length, waitingTime, reserved, train, feedbacks,
             entryFeedbackNext, brakeFeedbackNext, stopFeedbackNext,
             entryFeedbackPrevious, brakeFeedbackPrevious, stopFeedbackPrevious,
             center, angle
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(Identifier<Block>.self, forKey: CodingKeys.id)
        let name = try container.decode(String.self, forKey: CodingKeys.name)
        let category = try container.decode(Category.self, forKey: CodingKeys.type)
        let center = try container.decode(CGPoint.self, forKey: CodingKeys.center)
        let rotationAngle = try container.decode(Double.self, forKey: CodingKeys.angle)

        self.init(id: id, name: name, type: category, center: center, rotationAngle: rotationAngle)
        
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.enabled) ?? true
        self.length = try container.decodeIfPresent(Double.self, forKey: CodingKeys.length)
        self.waitingTime = try container.decodeIfPresent(TimeInterval.self, forKey: CodingKeys.waitingTime) ?? 10.0
        self.reserved = try container.decodeIfPresent(Reservation.self, forKey: CodingKeys.reserved)
        self.train = try container.decodeIfPresent(TrainInstance.self, forKey: CodingKeys.train)
        self.feedbacks = try container.decode([BlockFeedback].self, forKey: CodingKeys.feedbacks)
        
        self.entryFeedbackNext = try container.decodeIfPresent(Identifier<Feedback>.self, forKey: CodingKeys.entryFeedbackNext)
        self.brakeFeedbackNext = try container.decodeIfPresent(Identifier<Feedback>.self, forKey: CodingKeys.brakeFeedbackNext)
        self.stopFeedbackNext = try container.decodeIfPresent(Identifier<Feedback>.self, forKey: CodingKeys.stopFeedbackNext)
        
        self.entryFeedbackPrevious = try container.decodeIfPresent(Identifier<Feedback>.self, forKey: CodingKeys.entryFeedbackPrevious)
        self.brakeFeedbackPrevious = try container.decodeIfPresent(Identifier<Feedback>.self, forKey: CodingKeys.brakeFeedbackPrevious)
        self.stopFeedbackPrevious = try container.decodeIfPresent(Identifier<Feedback>.self, forKey: CodingKeys.stopFeedbackPrevious)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(enabled, forKey: CodingKeys.enabled)
        try container.encode(name, forKey: CodingKeys.name)
        try container.encode(category, forKey: CodingKeys.type)
        try container.encode(length, forKey: CodingKeys.length)
        try container.encode(waitingTime, forKey: CodingKeys.waitingTime)
        try container.encode(reserved, forKey: CodingKeys.reserved)
        try container.encode(train, forKey: CodingKeys.train)
        try container.encode(feedbacks, forKey: CodingKeys.feedbacks)

        try container.encode(entryFeedbackNext, forKey: CodingKeys.entryFeedbackNext)
        try container.encode(brakeFeedbackNext, forKey: CodingKeys.brakeFeedbackNext)
        try container.encode(stopFeedbackNext, forKey: CodingKeys.stopFeedbackNext)

        try container.encode(entryFeedbackPrevious, forKey: CodingKeys.entryFeedbackPrevious)
        try container.encode(brakeFeedbackPrevious, forKey: CodingKeys.brakeFeedbackPrevious)
        try container.encode(stopFeedbackPrevious, forKey: CodingKeys.stopFeedbackPrevious)

        try container.encode(center, forKey: CodingKeys.center)
        try container.encode(rotationAngle, forKey: CodingKeys.angle)
    }

}

extension Block.Category: CustomStringConvertible {
    var description: String {
        switch(self) {
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
