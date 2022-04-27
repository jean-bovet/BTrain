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

// See https://paul-samuels.com/blog/2019/01/02/swift-heterogeneous-codable-array/
enum RouteItem: Identifiable, Equatable, CustomStringConvertible {
    case block(RouteStep_Block)
    case turnout(RouteStep_Turnout)

    var id: String {
        switch self {
        case .block(let block): return block.id
        case .turnout(let turnout): return turnout.id
        }
    }
    
    var description: String {
        switch self {
        case .block(let block): return block.description
        case .turnout(let turnout): return turnout.description
        }
    }
    
    func entrySocketOrThrow() throws -> Socket {
        switch self {
        case .block(let block): return try block.entrySocketOrThrow()
        case .turnout(let turnout): return try turnout.entrySocketOrThrow()
        }
    }

    func entrySocketId() throws -> Int {
        switch self {
        case .block(let block): return try block.entrySocketId()
        case .turnout(let turnout): return try turnout.entrySocketId()
        }
    }

    func exitSocketOrThrow() throws -> Socket {
        switch self {
        case .block(let block): return try block.exitSocketOrThrow()
        case .turnout(let turnout): return try turnout.exitSocketOrThrow()
        }
    }

    func exitSocketId() throws -> Int {
        switch self {
        case .block(let block): return try block.exitSocketId()
        case .turnout(let turnout): return try turnout.exitSocketId()
        }
    }
}

extension RouteItem: Codable {
    
    var unassociated: Unassociated {
        switch self {
        case .block: return .block
        case .turnout: return .turnout
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        switch try container.decode(String.self, forKey: .type) {
        case Unassociated.block.rawValue: self = .block(try container.decode(RouteStep_Block.self, forKey: .attributes))
        case Unassociated.turnout.rawValue: self = .turnout(try container.decode(RouteStep_Turnout.self, forKey: .attributes))
        default: fatalError("Unknown type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .block(let block): try container.encode(block, forKey: .attributes)
        case .turnout(let turnout): try container.encode(turnout, forKey: .attributes)
        }

        try container.encode(unassociated.rawValue, forKey: .type)
    }
    
    enum Unassociated: String {
        case block
        case turnout
    }

    private enum CodingKeys: String, CodingKey {
        case attributes
        case type
    }
}
