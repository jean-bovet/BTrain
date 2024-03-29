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

/// This enumeration holds a single route item type and is used by the ``Route`` to create an array of route items.
///
/// A route is composed of one or more items. Each item is identified by this ``RouteItem`` that provides an enum
/// of the various types of items available.
///
/// See [this blog](https://paul-samuels.com/blog/2019/01/02/swift-heterogeneous-codable-array/)
enum RouteItem: Identifiable, Equatable {
    static func == (lhs: RouteItem, rhs: RouteItem) -> Bool {
        switch (lhs, rhs) {
        case let (.block(b1), .block(b2)):
            return b1.id == b2.id
        case let (.turnout(b1), .turnout(b2)):
            return b1.id == b2.id
        case let (.station(b1), .station(b2)):
            return b1.id == b2.id
        default:
            return false
        }
    }

    case block(RouteItemBlock)
    case turnout(RouteItemTurnout)
    case station(RouteItemStation)

    var id: String {
        switch self {
        case let .block(block): return block.id
        case let .turnout(turnout): return turnout.id
        case let .station(station): return station.id
        }
    }

    func description(_ layout: Layout) -> String {
        switch self {
        case let .block(block): return block.description(layout)
        case let .turnout(turnout): return turnout.description(layout)
        case let .station(station): return station.description(layout)
        }
    }
}

extension Array where Element == RouteItem {
    func description(_ layout: Layout) -> [String] {
        map { $0.description(layout) }
    }
}

extension RouteItem: Codable {
    var unassociated: Unassociated {
        switch self {
        case .block: return .block
        case .turnout: return .turnout
        case .station: return .station
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        switch try container.decode(String.self, forKey: .type) {
        case Unassociated.block.rawValue: self = .block(try container.decode(RouteItemBlock.self, forKey: .attributes))
        case Unassociated.turnout.rawValue: self = .turnout(try container.decode(RouteItemTurnout.self, forKey: .attributes))
        case Unassociated.station.rawValue: self = .station(try container.decode(RouteItemStation.self, forKey: .attributes))
        default: fatalError("Unknown type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .block(block): try container.encode(block, forKey: .attributes)
        case let .turnout(turnout): try container.encode(turnout, forKey: .attributes)
        case let .station(station): try container.encode(station, forKey: .attributes)
        }

        try container.encode(unassociated.rawValue, forKey: .type)
    }

    enum Unassociated: String {
        case block
        case turnout
        case station
    }

    private enum CodingKeys: String, CodingKey {
        case attributes
        case type
    }
}
