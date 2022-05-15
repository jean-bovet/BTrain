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
    enum State: String, Identifiable, Codable {
        var id: String {
            rawValue
        }
        
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
    
    @Published var category: Category = .singleLeft {
        didSet {
            requestedState = Turnout.defaultState(for: category)
            actualState = requestedState
            updateStateSpeedLimits()
        }
    }

    @Published var address: CommandTurnoutAddress = .init(0, .MM)
    @Published var address2: CommandTurnoutAddress = .init(0, .MM)

    // Length of the turnout (in cm)
    @Published var length: Double?
        
    // State of the turnout. Note that not all states are supported
    // by some turnout category.
    
    /// The state of the turnout that has been requested.
    ///
    /// It takes some time for the turnout to actually change in the physical layout. Once
    /// the Digital Controller sends the acknowledgment that the turnout has changed,
    /// the ``actualState`` will be updated to match the ``requestedState``.
    @Published var requestedState: State = .straight
    
    /// The most up-to-date state from the physical layout.
    ///
    /// It might differ from ``requestedState`` if the turnout hasn't physically yet changed.
    @Published var actualState: State = .straight
    
    /// Returns true if the turnout has settled.
    ///
    /// A turnout is settled when its actual state is the same as the requested state. In reality,
    /// a turnout takes some time to change the state on the physical layout which is why
    /// a turnout does not settled immediately.
    var settled: Bool {
        requestedState == actualState
    }
    
    struct Reservation: Codable, CustomStringConvertible {
        let train: Identifier<Train>
        
        struct Sockets: Codable {
            let fromSocketId: Int
            let toSocketId: Int
        }
        
        let sockets: Sockets?
        
        var description: String {
            if let sockets = sockets {
                return "\(train):\(sockets.fromSocketId)-\(sockets.toSocketId)"
            } else {
                return "\(train)"
            }
        }
    }

    enum SpeedLimit: String, Codable, CaseIterable {
        case unlimited
        case limited
    }

    typealias StateSpeedLimits = [State:SpeedLimit]
    
    // A dictionary of speed limit for each state of the turnout
    @Published var stateSpeedLimit = StateSpeedLimits()
    
    // Contains the reservation for the specified train
    var reserved: Reservation?
    
    // The identifier of the train located in this turnout
    var train: Identifier<Train>?

    var rotationAngle: CGFloat = 0
    var center: CGPoint = .zero

    var doubleAddress: Bool {
        return category == .doubleSlip2 ||
        category == .threeWay
    }
    
    init(id: Identifier<Turnout>, name: String = "") {
        self.id = id
        self.name = name
    }
    
    convenience init(name: String = UUID().uuidString) {
        self.init(id: Identifier<Turnout>(uuid: name), name: name)
    }
        
    func updateStateSpeedLimits() {
        let previous = stateSpeedLimit
        stateSpeedLimit.removeAll()
        for state in allStates {
            stateSpeedLimit[state] = previous[state] ?? defaultStateSpeedLimit(state)
        }
    }
    
    func defaultStateSpeedLimit(_ state: State) -> SpeedLimit {
        switch state {
        case .straight:
            return .unlimited
        case .branch:
            return .limited
        case .branchLeft:
            return .limited
        case .branchRight:
            return .limited
        case .straight01:
            return .unlimited
        case .straight23:
            return .unlimited
        case .branch03:
            return .limited
        case .branch21:
            return .limited
        case .invalid:
            return .limited
        }
    }
}

extension Turnout: Codable {
    
    enum CodingKeys: CodingKey {
      case id, enabled, type, name, address, address2, length, state, stateSpeedLimit, reserved, train, center, angle
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(Identifier<Turnout>.self, forKey: CodingKeys.id)

        self.init(id: id)
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.enabled) ?? true
        self.name = try container.decode(String.self, forKey: CodingKeys.name)
        self.category = try container.decode(Category.self, forKey: CodingKeys.type)
        self.address = try container.decode(CommandTurnoutAddress.self, forKey: CodingKeys.address)
        if let address2 = try container.decodeIfPresent(CommandTurnoutAddress.self, forKey: CodingKeys.address2) {
            self.address2 = address2
        }
        self.center = try container.decode(CGPoint.self, forKey: CodingKeys.center)
        self.rotationAngle = try container.decode(Double.self, forKey: CodingKeys.angle)
        self.length = try container.decodeIfPresent(Double.self, forKey: CodingKeys.length)
        self.requestedState = try container.decode(State.self, forKey: CodingKeys.state)
        self.actualState = self.requestedState
        if let reserved = try? container.decodeIfPresent(Identifier<Train>.self, forKey: CodingKeys.reserved) {
            self.reserved = .init(train: reserved, sockets: nil)
        } else {
            self.reserved = try container.decodeIfPresent(Turnout.Reservation.self, forKey: CodingKeys.reserved)
        }
        self.train = try container.decodeIfPresent(Identifier<Train>.self, forKey: CodingKeys.train)
        self.stateSpeedLimit = try container.decodeIfPresent(StateSpeedLimits.self, forKey: CodingKeys.stateSpeedLimit) ?? [:]
        
        updateStateSpeedLimits()
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
        try container.encode(requestedState, forKey: CodingKeys.state)
        try container.encode(stateSpeedLimit, forKey: CodingKeys.stateSpeedLimit)
        try container.encode(reserved, forKey: CodingKeys.reserved)
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
