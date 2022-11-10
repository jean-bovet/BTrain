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

/// This class represents a single locomotive in the layout.
final class Locomotive: Element, ObservableObject {
    /// Unique identifier of the locomotive
    let id: Identifier<Locomotive>
    
    /// True if enabled, false otherwise
    @Published var enabled = true
    
    /// Name of the locomotive
    @Published var name = ""

    /// Address of the locomotive
    @Published var address: UInt32 = 0
      
    /// The decoder type of the locomotive
    @Published var decoder: DecoderType = .MFX {
        didSet {
            speed.decoderType = decoder
        }
    }
    
    /// Length of the locomotive (in cm)
    @Published var length: Double?
    
    /// Speed of the locomotive
    @Published var speed = LocomotiveSpeed(kph: 0, decoderType: .MFX)

    /// Direction of travel of the locomotive
    /// Note: backward direction is not yet supported
    @Published var directionForward = true
    
    /// True if the locomotive can move in the backward direction
    @Published var canMoveBackwards = false
    
    convenience init(uuid: String = UUID().uuidString, name: String = "", address: UInt32 = 0, decoder: DecoderType = .MFX,
                     locomotiveLength: Double? = nil, maxSpeed: LocomotiveSpeed.UnitKph? = nil) {
        self.init(id: Identifier(uuid: uuid), name: name, address: address, decoder: decoder,
                  locomotiveLength: locomotiveLength, maxSpeed: maxSpeed)
    }
    
    init(id: Identifier<Locomotive>, name: String, address: UInt32, decoder: DecoderType = .MFX,
         locomotiveLength: Double? = nil, maxSpeed: LocomotiveSpeed.UnitKph? = nil) {
        self.id = id
        self.name = name
        self.address = address
        self.length = locomotiveLength
        self.speed.maxSpeed = maxSpeed ?? self.speed.maxSpeed
    }

}

extension Locomotive: Codable {
    
    enum CodingKeys: CodingKey {
      case id, enabled, name, address, locomotiveLength, speed, acceleration, stopSettleDelay, decoder, direction
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(Identifier<Locomotive>.self, forKey: CodingKeys.id)
        let name = try container.decode(String.self, forKey: CodingKeys.name)
        let address = try container.decode(UInt32.self, forKey: CodingKeys.address)

        self.init(id: id, name: name, address: address)
        
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.enabled) ?? true
        self.decoder = try container.decode(DecoderType.self, forKey: CodingKeys.decoder)
        self.length = try container.decodeIfPresent(Double.self, forKey: CodingKeys.locomotiveLength)
        self.speed = try container.decode(LocomotiveSpeed.self, forKey: CodingKeys.speed)
        self.directionForward = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.direction) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(enabled, forKey: CodingKeys.enabled)
        try container.encode(name, forKey: CodingKeys.name)
        try container.encode(address, forKey: CodingKeys.address)
        try container.encode(decoder, forKey: CodingKeys.decoder)
        try container.encode(speed, forKey: CodingKeys.speed)
        try container.encode(directionForward, forKey: CodingKeys.direction)
    }

}

extension Array where Element : Locomotive {

    func find(address: UInt32, decoder: DecoderType?) -> Element? {
        self.first { loc in
            loc.address.actualAddress(for: loc.decoder) == address.actualAddress(for: decoder)
        }
    }
    
}
