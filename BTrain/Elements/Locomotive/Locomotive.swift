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
    @Published var length: DistanceCm?

    /// Speed of the locomotive
    @Published var speed = LocomotiveSpeed(kph: 0, decoderType: .MFX)

    /// Direction of travel of the locomotive
    @Published var directionForward = true

    enum AllowedDirection: String, Codable, CaseIterable {
        case forward
        case any // forward and backward
    }
    
    /// Direction(s) the locomotive is allowed to move
    @Published var allowedDirections = AllowedDirection.forward
    
    /// The functions associated with this locomotive
    @Published var functions = [CommandLocomotiveFunction]()

    convenience init(uuid: String = UUID().uuidString, name: String = "", address: UInt32 = 0, decoder: DecoderType = .MFX,
                     locomotiveLength: Double? = nil, maxSpeed: SpeedKph? = nil)
    {
        self.init(id: Identifier(uuid: uuid), name: name, address: address, decoder: decoder,
                  locomotiveLength: locomotiveLength, maxSpeed: maxSpeed)
    }

    init(id: Identifier<Locomotive>, name: String, address: UInt32, decoder _: DecoderType = .MFX,
         locomotiveLength: Double? = nil, maxSpeed: SpeedKph? = nil)
    {
        self.id = id
        self.name = name
        self.address = address
        length = locomotiveLength
        speed.maxSpeed = maxSpeed ?? speed.maxSpeed
    }
}

extension Locomotive: Codable {
    enum CodingKeys: CodingKey {
        case id, enabled, name, address, lenght, speed, decoder, direction, allowedDirections, functions
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(Identifier<Locomotive>.self, forKey: CodingKeys.id)
        let name = try container.decode(String.self, forKey: CodingKeys.name)
        let address = try container.decode(UInt32.self, forKey: CodingKeys.address)

        self.init(id: id, name: name, address: address)

        enabled = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.enabled) ?? true
        self.decoder = try container.decode(DecoderType.self, forKey: CodingKeys.decoder)
        length = try container.decodeIfPresent(Double.self, forKey: CodingKeys.lenght)
        speed = try container.decode(LocomotiveSpeed.self, forKey: CodingKeys.speed)
        directionForward = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.direction) ?? true
        allowedDirections = try container.decodeIfPresent(AllowedDirection.self, forKey: CodingKeys.allowedDirections) ?? .forward
        functions = try container.decodeIfPresent([CommandLocomotiveFunction].self, forKey: CodingKeys.functions) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(enabled, forKey: CodingKeys.enabled)
        try container.encode(name, forKey: CodingKeys.name)
        try container.encode(address, forKey: CodingKeys.address)
        try container.encode(length, forKey: CodingKeys.lenght)
        try container.encode(speed, forKey: CodingKeys.speed)
        try container.encode(decoder, forKey: CodingKeys.decoder)
        try container.encode(directionForward, forKey: CodingKeys.direction)
        try container.encode(allowedDirections, forKey: CodingKeys.allowedDirections)
        try container.encode(functions, forKey: CodingKeys.functions)
    }
}

extension Array where Element: Locomotive {
    func find(address: UInt32, decoder: DecoderType?) -> Element? {
        first { loc in
            loc.address.actualAddress(for: loc.decoder) == address.actualAddress(for: decoder)
        }
    }
}
