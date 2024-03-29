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

/// This enum describes a resolved route item.
///
/// Note that a resolved route item does not include a station, because a station needs to be resolved to a single
/// block in order to be included in the route.
enum ResolvedRouteItem: CustomStringConvertible {
    /// A resolved item describing a block
    case block(ResolvedRouteItemBlock)

    /// A resolved item describing a turnout
    case turnout(ResolvedRouteItemTurnout)

    var entrySocket: Socket {
        switch self {
        case let .block(resolvedRouteItemBlock):
            return Socket.block(resolvedRouteItemBlock.block.id, socketId: resolvedRouteItemBlock.entrySocketId)
        case let .turnout(resolvedRouteItemTurnout):
            return Socket.turnout(resolvedRouteItemTurnout.turnout.id, socketId: resolvedRouteItemTurnout.entrySocketId)
        }
    }

    var exitSocket: Socket {
        switch self {
        case let .block(resolvedRouteItemBlock):
            return Socket.block(resolvedRouteItemBlock.block.id, socketId: resolvedRouteItemBlock.exitSocketId)
        case let .turnout(resolvedRouteItemTurnout):
            return Socket.turnout(resolvedRouteItemTurnout.turnout.id, socketId: resolvedRouteItemTurnout.exitSocketId)
        }
    }

    var description: String {
        switch self {
        case let .block(block):
            return block.description
        case let .turnout(turnout):
            return turnout.description
        }
    }
}

struct ResolvedRouteItemBlock: CustomStringConvertible {
    let block: Block
    let entrySocketId: SocketId
    let exitSocketId: SocketId

    var blockId: Identifier<Block> {
        block.id
    }

    var direction: Direction {
        exitSocketId == Block.nextSocket ? .next : .previous
    }

    var description: String {
        "\(blockId):\(direction)"
    }

    init(block: Block, direction: Direction) {
        self.block = block
        switch direction {
        case .previous:
            entrySocketId = Block.nextSocket
            exitSocketId = Block.previousSocket
        case .next:
            entrySocketId = Block.previousSocket
            exitSocketId = Block.nextSocket
        }
    }
}

struct ResolvedRouteItemTurnout: CustomStringConvertible {
    let turnout: Turnout
    let entrySocketId: SocketId
    let exitSocketId: SocketId

    var description: String {
        "\(turnout.id):(\(entrySocketId)>\(exitSocketId))"
    }
}
