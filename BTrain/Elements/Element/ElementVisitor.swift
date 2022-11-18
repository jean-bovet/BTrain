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

// This class is used to visit the elements of the layout in a specific direction,
// receiving a callback for each element visited (transition, turnout and block).
// At the moment, this class follows the current state of each turnout.
final class ElementVisitor {
    let layout: Layout

    init(layout: Layout) {
        self.layout = layout
    }

    struct TurnoutInfo {
        let turnout: Turnout
        let sockets: Turnout.Reservation.Sockets?
    }

    struct BlockInfo {
        let block: Block

        // Direction in which the visitor algorithm is traversing the block
        let direction: Direction
    }

    struct ElementInfo {
        let transition: ITransition?
        let turnout: TurnoutInfo?
        let block: BlockInfo?

        // Index of the element the visitor algorithm is visiting
        let index: Int

        static func block(_ block: Block, direction: Direction, index: Int) -> ElementInfo {
            .init(transition: nil, turnout: nil, block: .init(block: block, direction: direction), index: index)
        }

        static func transition(_ transition: ITransition, index: Int) -> ElementInfo {
            .init(transition: transition, turnout: nil, block: nil, index: index)
        }

        static func turnout(_ turnout: Turnout, sockets: Turnout.Reservation.Sockets?, index: Int) -> ElementInfo {
            .init(transition: nil, turnout: .init(turnout: turnout, sockets: sockets), block: nil, index: index)
        }
    }

    enum VisitorCallbackResult {
        case stop
        case `continue`
    }

    typealias VisitorCallback = (ElementInfo) throws -> VisitorCallbackResult

    static func blockAfter(block: Block, direction: Direction, layout: Layout) throws -> Block? {
        var nextBlock: Block?
        let visitor = ElementVisitor(layout: layout)
        try visitor.visit(fromBlockId: block.id, toBlockId: nil, direction: direction) { info in
            if let block = info.block, info.index > 0 {
                nextBlock = block.block
                return .stop
            } else {
                return .continue
            }
        }
        return nextBlock
    }

    // If toBlockId = nil, the algorithm follows the turnout and transitions until it cannot go any further.
    // If toBlockId != nil, the algorithm stops when the toBlockId is reached.
    func visit(fromBlockId: Identifier<Block>, toBlockId: Identifier<Block>? = nil, direction: Direction, callback: VisitorCallback) throws {
        guard let block = layout.blocks[fromBlockId] else {
            throw LayoutError.blockNotFound(blockId: fromBlockId)
        }
        guard try callback(ElementInfo.block(block, direction: direction, index: 0)) == .continue else {
            return
        }
        let toBlock = layout.blocks[toBlockId]
        let fromSocket = direction == .next ? block.next : block.previous
        try visit(fromSocket: fromSocket, toBlock: toBlock, index: 1, callback: callback)
    }

    private func visit(fromSocket: Socket, toBlock: Block?, index: Int, callback: VisitorCallback) throws {
        guard let transition = try layout.transition(from: fromSocket) else {
            return
        }

        guard try callback(ElementInfo.transition(transition, index: index)) == .continue else {
            return
        }

        // Transitions are always ordered with a being "from" and b "to" - see self.transitions() method
        guard let toSocketId = transition.b.socketId else {
            throw LayoutError.socketIdNotFound(socket: transition.b)
        }

        if let blockId = transition.b.block {
            // Transition is leading to a block
            guard let block = layout.blocks[blockId] else {
                throw LayoutError.blockNotFound(blockId: blockId)
            }

            let direction: Direction = toSocketId == block.previous.socketId ? .next : .previous
            guard try callback(ElementInfo.block(block, direction: direction, index: index)) == .continue else {
                return
            }

            // Stop the visit once we reached the destination block, if specified
            if let toBlock = toBlock, toBlock == block {
                return
            }

            // Recursively call this method again to continue the job in the next element
            if direction == .next {
                try visit(fromSocket: block.next, toBlock: toBlock, index: index + 1, callback: callback)
            } else {
                try visit(fromSocket: block.previous, toBlock: toBlock, index: index + 1, callback: callback)
            }
        } else if let turnoutId = transition.b.turnout {
            // Transition is leading to a turnout
            guard let turnout = layout.turnouts[turnoutId] else {
                throw LayoutError.turnoutNotFound(turnoutId: turnoutId)
            }

            var sockets: Turnout.Reservation.Sockets?

            if let toBlock = toBlock {
                // If the destination block is specified, we need to find out which exit socket of the turnout to use
                if let exitSocketId = try exitSocketOf(turnout: turnout, fromSocketId: toSocketId, toReachBlock: toBlock) {
                    sockets = .init(fromSocketId: toSocketId, toSocketId: exitSocketId)
                }
            } else {
                // Find out the exit socket of the turnout given its state.
                // Note that it can happen that a turnout is configured for another route and exitSocketId will be nil here.
                if let exitSocketId = turnout.socketId(fromSocketId: toSocketId, withState: turnout.requestedState) {
                    sockets = .init(fromSocketId: toSocketId, toSocketId: exitSocketId)
                }
            }

            guard try callback(ElementInfo.turnout(turnout, sockets: sockets, index: index)) == .continue else {
                return
            }

            if let sockets = sockets {
                // Recursively call this method again to continue the job in the next element
                try visit(fromSocket: turnout.socket(sockets.toSocketId), toBlock: toBlock, index: index + 1, callback: callback)
            }
        }
    }

    // This method returns the exit socket for the specified turnout, reachable from the `fromSocketId`,
    // that ultimately reaches the `toReachBlock`. This method does not search more than one block ahead,
    // but with unlimited number of turnouts chained together.
    func exitSocketOf(turnout: Turnout, fromSocketId: Int, toReachBlock: Block) throws -> Int? {
        for candidate in turnout.sockets(from: fromSocketId) {
            guard let transition = try layout.transition(from: turnout.socket(candidate)) else {
                continue
            }
            if let blockId = transition.b.block {
                if blockId == toReachBlock.id {
                    return candidate
                } else {
                    // We stop at the first block we find that is not matching toReachBlock
                    return nil
                }
            } else if let turnoutId = transition.b.turnout, let turnout = layout.turnouts[turnoutId], let socketId = transition.b.socketId {
                if let socket = try exitSocketOf(turnout: turnout, fromSocketId: socketId, toReachBlock: toReachBlock) {
                    return socket
                }
            }
        }

        return nil
    }
}
