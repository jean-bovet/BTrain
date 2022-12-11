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

struct RouteScriptCommand: ScriptCommand, Identifiable, Hashable {
    let id: UUID

    enum Action: String, CaseIterable, Codable {
        case start = "Start"
        case move = "Move"
        case loop = "Repeat"
    }

    var action: Action = .move

    var children = [RouteScriptCommand]()
    var repeatCount = 0
    var waitDuration = 0

    enum MoveDestinationType: String, CaseIterable, Codable {
        case block
        case station
    }

    var destinationType = MoveDestinationType.block

    var blockId: Identifier<Block>?
    var direction: Direction?
    var stationId: Identifier<Station>?

    struct Function: Identifiable, Hashable, Codable {
        var id = UUID().uuidString
        var type: UInt32
        var enabled: Bool
        @DecodableDefault.Zero var duration: TimeInterval
    }

    var functions = [Function]()
    
    init(id: UUID = UUID(), action: Action) {
        self.id = id
        self.action = action
    }
}

extension RouteScriptCommand: Codable {
    enum CodingKeys: CodingKey {
        case id, action, children, repeatCount, waitDuration, destinationType, blockId, direction, stationId, functions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: CodingKeys.id)
        action = try container.decode(Action.self, forKey: CodingKeys.action)
        children = try container.decode([RouteScriptCommand].self, forKey: CodingKeys.children)
        repeatCount = try container.decode(Int.self, forKey: CodingKeys.repeatCount)
        waitDuration = try container.decode(Int.self, forKey: CodingKeys.waitDuration)

        destinationType = try container.decode(MoveDestinationType.self, forKey: CodingKeys.destinationType)
        blockId = try container.decodeIfPresent(Identifier<Block>.self, forKey: CodingKeys.blockId)
        direction = try container.decodeIfPresent(Direction.self, forKey: CodingKeys.direction)
        stationId = try container.decodeIfPresent(Identifier<Station>.self, forKey: CodingKeys.stationId)
        functions = try container.decodeIfPresent([Function].self, forKey: CodingKeys.functions) ?? []
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
        try container.encode(direction, forKey: CodingKeys.direction)
        try container.encode(stationId, forKey: CodingKeys.stationId)
        try container.encode(functions, forKey: CodingKeys.functions)
    }
}
