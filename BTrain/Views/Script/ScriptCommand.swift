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

struct ScriptCommand: Identifiable, Hashable {
    
    let id: UUID
    
    enum ScriptAction: String, CaseIterable, Codable {
        case move = "Move"
        case loop = "Repeat"
        case wait = "Wait"
    }

    var action: ScriptAction = .move
    
    var children = [ScriptCommand]()
    var repeatCount = 0
    var waitDuration = 0
    
    enum MoveDestinationType: String, CaseIterable, Codable {
        case block
        case station
    }

    var destinationType = MoveDestinationType.block
    
    var blockId: Identifier<Block>?
    var stationId: Identifier<Station>?
    
    init(id: UUID = UUID(), action: ScriptAction) {
        self.id = id
    }
}

extension ScriptCommand: Codable {
    
    enum CodingKeys: CodingKey {
        case id, action, children, repeatCount, waitDuration, destinationType, blockId, stationId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: CodingKeys.id)
        self.action = try container.decode(ScriptAction.self, forKey: CodingKeys.action)
        self.children = try container.decode([ScriptCommand].self, forKey: CodingKeys.children)
        self.repeatCount = try container.decode(Int.self, forKey: CodingKeys.repeatCount)
        self.waitDuration = try container.decode(Int.self, forKey: CodingKeys.waitDuration)

        self.destinationType = try container.decode(MoveDestinationType.self, forKey: CodingKeys.destinationType)
        self.blockId = try container.decodeIfPresent(Identifier<Block>.self, forKey: CodingKeys.blockId)
        self.stationId = try container.decodeIfPresent(Identifier<Station>.self, forKey: CodingKeys.stationId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(action, forKey: CodingKeys.action)
        try container.encode(children, forKey: CodingKeys.children)
        try container.encode(repeatCount, forKey: CodingKeys.repeatCount)
        try container.encode(waitDuration, forKey: CodingKeys.waitDuration)
        try container.encode(destinationType, forKey: CodingKeys.destinationType)
        try container.encode(blockId, forKey: CodingKeys.blockId)
        try container.encode(stationId, forKey: CodingKeys.stationId)
    }
}
