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
//            Feedback                       Block Direction
//               │                                  │
//  Socket       │                  Train           │
//    │          │                    │             │
//    │          │                    │             │
//    │          │                    │             │
//    │          ▼                    │             ▼
//    │  ╲       ██            ██     │      ██    ╲
//    ▼   ╲      ██            ██     ▼      ██     ╲
//  ──○────■─────██────────────██─────■■▶────██──────■────○──
//    0   ╱      ██            ██            ██     ╱     1
//       ╱       ██            ██            ██    ╱
//
//               f0            f1            f2

// This protocol exposes several properties of the block in a read-only manner,
// in order to avoid any unwanted mutation.
// Any mutation on the block object should happen within the Layout object to ensure consistency.
protocol IBlock: AnyObject {
    // The unique identifier of the block
    var id: Identifier<Block> { get }
    
    // True if the block is enabled and ready to participate
    // in the routing. False to have the block ignored
    // by any routing, which is useful when a block is occupied
    // or in need of repair and we don't want to have a train
    // stopping or running through it.
    var enabled: Bool { get }
    
    // The name of the block
    var name: String { get }
    
    // The category of the block
    var category: Block.Category { get }
    
    // Indicates if that block is reserved for a particular train.
    // A reserved block does not necessarily have a train in it.
    var reserved: Reservation? { get }

    // Returns the current train (and its direction of travel) inside this block
    var train: Block.TrainInstance? { get }

    // Returns true if the train is traveling along the natural direction of the block
    var trainNaturalDirection: Bool { get }
    
    // Returns the list of feedbacks in this block
    var feedbacks: [Block.BlockFeedback] { get }
    
    // Returns the socket from the "previous" side
    var previous: Socket { get }
    
    // Returns the socket from the "next" side
    var next: Socket { get }
    
    // Returns a socket that does not have any side indication,
    // which can be useful when we want to refer to "any socket
    // from block" in transitions calculation.
    var any: Socket { get }
    
    // Returns all the sockets
    var allSockets: [Socket] { get }
    
    // Returns the name of the specific socket
    func socketName(_ socketId: Int) -> String
}

// Semi-mutable block protocol that allows for only the geometry to be changed
protocol BlockGeometry: IBlock {
    // Center of the block
    var center: CGPoint { get set }
        
    // Rotation angle of the block, in radian.
    var rotationAngle: CGFloat { get set }
}

// This is the concrete (and mutable) implementation of a block
final class Block: Element, BlockGeometry, ObservableObject {
    
    // Defines the train in the block, which is the train
    // itself and its direction of travel within the block
    struct TrainInstance: Codable, Equatable, CustomStringConvertible {
        
        let trainId: Identifier<Train>
        let direction: Direction
        
        init(_ trainId: Identifier<Train>, _ direction: Direction) {
            self.trainId = trainId
            self.direction = direction
        }
        
        var description: String {
            return "TrainInstance(\(trainId), \(direction.rawValue))"
        }
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

    let id: Identifier<Block>

    var enabled = true
    
    var name: String
    
    @Published var category: Category
    
    var center: CGPoint = .zero
    var rotationAngle: CGFloat = 0

    @Published var reserved: Reservation?
    
    @Published var train: TrainInstance?
    
    var trainNaturalDirection: Bool {
        guard let train = train else {
            preconditionFailure("It is an error to ask for the natural direction of the train in block \(id) because it does not contain the train instance")
        }
        return train.direction == .next
    }

    // A structure identifying each feedback inside this block
    struct BlockFeedback: Identifiable, Hashable, Codable {
        let id: String
        var feedbackId: Identifier<Feedback>
    }
    
    @Published var feedbacks = [BlockFeedback]()
                
    // Returns the integer that indicates the "previous" socket
    static var previousSocket: Int {
        return 0
    }
    
    // Returns the integer that indicates the "next" socket
    static var nextSocket: Int {
        return 1
    }
    
    var previous: Socket {
        return Socket.block(id, socketId: Block.previousSocket)
    }

    var next: Socket {
        return Socket.block(id, socketId: Block.nextSocket)
    }
    
    var any: Socket {
        return Socket.block(id)
    }
    
    var allSockets: [Socket] {
        switch(category) {
        case .station, .free:
            return [previous, next]
        case .sidingPrevious:
            return [next]
        case .sidingNext:
            return [previous]
        }
    }
    
    func socketName(_ socketId: Int) -> String {
        switch(socketId) {
        case 0:
            return "previous"
        case 1:
            return "next"
        default:
            return "?"
        }
    }

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
    
    func assign(_ feedbackIds: [Identifier<Feedback>]) {
        feedbacks = feedbackIds.map { BlockFeedback(id: UUID().uuidString, feedbackId: $0) }
    }
    
    func remove(_ feedback: BlockFeedback) {
        feedbacks.removeAll(where: { $0.id == feedback.id })
    }
    
    func add(_ feedbackId: Identifier<Feedback>) {
        feedbacks.append(BlockFeedback(id: UUID().uuidString, feedbackId: feedbackId))
    }
    
    func remove(feedbackId: Identifier<Feedback>) {
        feedbacks.removeAll(where: { $0.feedbackId == feedbackId })
    }
    
}

extension Block: Codable {
    
    enum CodingKeys: CodingKey {
        case id, enabled, name, type, reserved, train, feedbacks, center,angle
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
        self.reserved = try container.decodeIfPresent(Reservation.self, forKey: CodingKeys.reserved)
        self.train = try container.decodeIfPresent(TrainInstance.self, forKey: CodingKeys.train)
        self.feedbacks = try container.decode([BlockFeedback].self, forKey: CodingKeys.feedbacks)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(enabled, forKey: CodingKeys.enabled)
        try container.encode(name, forKey: CodingKeys.name)
        try container.encode(category, forKey: CodingKeys.type)
        try container.encode(reserved, forKey: CodingKeys.reserved)
        try container.encode(train, forKey: CodingKeys.train)
        try container.encode(feedbacks, forKey: CodingKeys.feedbacks)
        
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
