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

// Defines a specific reservation of a train in a block or turnout.
struct Reservation: Codable, Equatable, CustomStringConvertible {
    let trainId: Identifier<Train>
    
    // Expected direction of travel of the train in the block.
    // Mainly used in the UX to indicate the direction of travel
    // but ignored internally when checking if a block is reserved
    // (only the trainId matters).
    let direction: Direction

    // True if this reservation is ahead of the train. This is used
    // by the controller to know which blocks have been reserved ahead
    // of the train so it can make various prediction on them.
    // This variable is set to false as soon as the train enters a block
    // with that reservation.
    var leading = true

    var description: String {
        return "Reservation(train=\(trainId), direction=\(direction.rawValue), leading=\(leading))"
    }

    // Because `direction` is only an optional information,
    // it is not considered in the equality of the reservation
    static func ==(lhs: Reservation, rhs: Reservation) -> Bool {
        return lhs.trainId == rhs.trainId
    }

    enum CodingKeys: CodingKey {
      case trainId, direction, leading
    }

    init(trainId: Identifier<Train>, direction: Direction, leading: Bool = true) {
        self.trainId = trainId
        self.direction = direction
        self.leading = leading
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(trainId: try container.decode(Identifier<Train>.self, forKey: CodingKeys.trainId),
                  direction: try container.decode(Direction.self, forKey: CodingKeys.direction),
                  leading: try container.decodeIfPresent(Bool.self, forKey: CodingKeys.leading) ?? false)
    }
 
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(trainId, forKey: CodingKeys.trainId)
        try container.encode(direction, forKey: CodingKeys.direction)
        try container.encode(leading, forKey: CodingKeys.leading)
    }
    
}
