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

// This class is used to represent a train inside one or more block. While the Train class represents
// a train, the TrainInstance represents that train over one or more block depending on the length of the train.
final class TrainInstance: Codable, Equatable, CustomStringConvertible {
    // Reference to the actual train this instance is representing
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
    
    var description: String {
        "TrainInstance(\(trainId), \(direction.rawValue))"
    }

    static func == (lhs: TrainInstance, rhs: TrainInstance) -> Bool {
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
