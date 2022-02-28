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

// This class defines a turnout in the layout.
final class Turnout: Element, ObservableObject {

    // The various types of turnouts that are supported
    enum Category: String, Codable, CaseIterable {
        case singleLeft
        case singleRight
        case threeWay
        case doubleSlip // Double slip with a single address (only two states)
        case doubleSlip2 // Double slip with two addresses (4 states)
    }

    // The various states supported by the turnout
    enum State: String, Codable {
        case straight
        case branch // Used for Double Slip with 2 states (straight and branch)
        case branchLeft
        case branchRight
        case straight01
        case straight23
        case branch03
        case branch21
        case invalid
    }

    let id: Identifier<Turnout>
                
    // True if the turnout is enabled and ready to participate
    // in the routing. False to have the turnout ignored
    // by any routing, which is useful when a turnout is in need of repair
    // and we don't want to have a train running through it.
    @Published var enabled = true

    @Published var name = ""
    
    @Published var category: Category = .singleLeft

    @Published var address: CommandTurnoutAddress = .init(0, .MM)
    @Published var address2: CommandTurnoutAddress = .init(0, .MM)

    // Length of the turnout (in cm)
    @Published var length: Double?
        
    // State of the turnout. Note that not all states are supported
    // by some turnout category.
    @Published var state: State = .straight
        
    // Contains the reservation for the specified train
    var reserved: Identifier<Train>?

    struct SocketReservation: Codable {
        let fromSocketId: Int
        let toSocketId: Int
    }

    var reservedSockets: SocketReservation?
    
    // The identifier of the train located in this turnout
    var train: Identifier<Train>?

    var rotationAngle: CGFloat = 0
    var center: CGPoint = .zero

    var doubleAddress: Bool {
        return category == .doubleSlip2 ||
        category == .threeWay
    }
    
    init(id: Identifier<Turnout>, name: String, type: Category, address: CommandTurnoutAddress, address2: CommandTurnoutAddress? = nil,
         state: State = .straight, center: CGPoint, rotationAngle: CGFloat, length: Double? = nil) {
        self.id = id
        self.name = name
        self.category = type
        self.address = address
        if let address2 = address2 {
            self.address2 = address2
        }
        self.state = state
        self.center = center
        self.rotationAngle = rotationAngle
        self.length = length
    }

    convenience init(_ uuid: String = UUID().uuidString, type: Category, address: CommandTurnoutAddress, address2: CommandTurnoutAddress? = nil, state: State = .straight, center: CGPoint = .zero, rotationAngle: CGFloat = 0, length: Double? = nil) {
        self.init(id: Identifier(uuid: uuid), name: uuid, type: type, address: address, address2: address2, state: state, center: center, rotationAngle: rotationAngle, length: length)
    }
    
}

extension Turnout: Codable {
    
    enum CodingKeys: CodingKey {
      case id, enabled, type, name, address, address2, length, state, reserved, reservedSockets, train, center, angle
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(Identifier<Turnout>.self, forKey: CodingKeys.id)
        let name = try container.decode(String.self, forKey: CodingKeys.name)
        let type = try container.decode(Category.self, forKey: CodingKeys.type)
        let address = try container.decode(CommandTurnoutAddress.self, forKey: CodingKeys.address)
        let address2 = try container.decodeIfPresent(CommandTurnoutAddress.self, forKey: CodingKeys.address2)
        let center = try container.decode(CGPoint.self, forKey: CodingKeys.center)
        let rotationAngle = try container.decode(Double.self, forKey: CodingKeys.angle)
        let length = try container.decodeIfPresent(Double.self, forKey: CodingKeys.length)
        let state = try container.decode(State.self, forKey: CodingKeys.state)

        self.init(id: id, name: name, type: type, address: address, address2: address2, state: state, center: center, rotationAngle: rotationAngle, length: length)
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.enabled) ?? true
        self.reserved = try container.decodeIfPresent(Identifier<Train>.self, forKey: CodingKeys.reserved)
        self.reservedSockets = try container.decodeIfPresent(Turnout.SocketReservation.self, forKey: CodingKeys.reservedSockets)
        self.train = try container.decodeIfPresent(Identifier<Train>.self, forKey: CodingKeys.train)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(enabled, forKey: CodingKeys.enabled)
        try container.encode(name, forKey: CodingKeys.name)
        try container.encode(category, forKey: CodingKeys.type)
        try container.encode(address, forKey: CodingKeys.address)
        try container.encode(address2, forKey: CodingKeys.address2)
        try container.encode(length, forKey: CodingKeys.length)
        try container.encode(state, forKey: CodingKeys.state)
        try container.encode(reserved, forKey: CodingKeys.reserved)
        try container.encode(reservedSockets, forKey: CodingKeys.reservedSockets)
        try container.encode(train, forKey: CodingKeys.train)

        try container.encode(center, forKey: CodingKeys.center)
        try container.encode(rotationAngle, forKey: CodingKeys.angle)
    }
    
}

extension Turnout.Category: CustomStringConvertible {    
    var description: String {
        switch(self) {
        case .singleLeft:
            return "Turnout Left"
        case .singleRight:
            return "Turnout Right"
        case .threeWay:
            return "Turnout 3-Way"
        case .doubleSlip:
            return "Double Slip (2 states)"
        case .doubleSlip2:
            return "Double Slip (4 states)"
        }
    }
}

extension Turnout.State: CustomStringConvertible {
    var description: String {
        switch(self) {
        case .straight:
            return "Straight"
        case .branch:
            return "Branch"
        case .branchLeft:
            return "Branch Left"
        case .branchRight:
            return "Branch Right"
        case .straight01:
            return "Straight 0-1"
        case .straight23:
            return "Straight 2-3"
        case .branch03:
            return "Branch 0-3"
        case .branch21:
            return "Branch 2-1"
        case .invalid:
            return "Invalid"
        }
    }
}

extension Array where Element : Turnout {

    func find(address: CommandTurnoutAddress) -> Element? {
        return self.first { turnout in
            return turnout.address.actualAddress == address.actualAddress ||
            turnout.address2.actualAddress == address.actualAddress
        }
    }
    
}
