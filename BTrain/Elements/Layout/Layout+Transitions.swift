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

extension Layout {
    func link(_ id: String, from: Socket, to: Socket) {
        add(Transition(id: id, a: from, b: to))
    }

    func link(from: Socket, to: Socket) {
        add(Transition(id: LayoutIdentity.newIdentity(transitions.elements, prefix: .transition), a: from, b: to))
    }

    func add(_ transition: Transition) {
        guard transitions.elements.first(where: { $0.same(as: transition) }) == nil else {
            return
        }
        transitions.add(transition)
    }

    func remove(transitionID: Identifier<Transition>) {
        transitions.elements.removeAll(where: { $0.id == transitionID })
    }

    func transitions(from fromBlock: Identifier<Block>, to nextBlock: Identifier<Block>, direction: Direction) throws -> [Transition] {
        guard let b1 = blocks[fromBlock] else {
            throw LayoutError.blockNotFound(blockId: fromBlock)
        }
        guard let b2 = blocks[nextBlock] else {
            throw LayoutError.blockNotFound(blockId: nextBlock)
        }
        return try transitions(from: LayoutVector(block: b1, direction: direction), to: LayoutVector(block: b2, direction: nil))
    }

    func transitions(from fromBlock: LayoutVector, to nextBlock: LayoutVector) throws -> [Transition] {
        try transitions(from: fromBlock.exitSocket, to: nextBlock.entrySocket)
    }

    // Returns the transition from the specified socket. There is either no transition
    // or a single transition out of a socket.
    // An exception is thrown if more than one transition is found because this is an error.
    func transition(from: Socket) throws -> Transition? {
        let candidates: [Transition] = transitions.elements.compactMap { transition in
            if transition.a.contains(other: from) {
                return transition
            } else if transition.b.contains(other: from) {
                return transition.reverse
            } else {
                return nil
            }
        }

        switch candidates.count {
        case 0:
            return nil
        case 1:
            return candidates[0]
        default:
            // Check that there is only one and one transition only
            // that starts from the `from` socket because a socket
            // supports only one transition out of it!
            throw LayoutError.alwaysOneAndOnlyOneTransition
        }
    }

    // This method returns all the transitions between two sockets. A socket
    // can be either the start/end of a block or a turnout. For example,
    // it will return two transitions between block 1 and block 2:
    // ┌─────────┐                     ┌─────────┐
    // │ Block 1 │────▶  Turnout  ────▶│ Block 2 │
    // └─────────┘                     └─────────┘
    func transitions(from: Socket, to: Socket) throws -> [Transition] {
        // Find out all the transitions (candidates) that start or end with the "from" socket.
        // For example, a transition between a block and a turnout can be represented by:
        // ┌─────────┐
        // │ Block 1 │b─────────a  Turnout
        // └─────────┘
        // Or:
        // ┌─────────┐
        // │ Block 1 │a─────────b  Turnout
        // └─────────┘
        // The same between two blocks (or two turnouts):
        // ┌─────────┐           ┌─────────┐
        // │ Block 1 │b─────────a│ Block 2 │
        // └─────────┘           └─────────┘
        // Or:
        // ┌─────────┐           ┌─────────┐
        // │ Block 1 │a─────────b│ Block 2 │
        // └─────────┘           └─────────┘
        guard let transition = try transition(from: from) else {
            return []
        }

        if transition.b == to {
            // If the transition ends at the "to" socket, we can return it now.
            return [transition]
        } else if let turnoutId = transition.b.turnout {
            // If the transition ends at a turnout, iterate over all the sockets
            // until a transition to the `to` socket is found.
            guard let turnout = turnouts[turnoutId] else {
                throw LayoutError.turnoutNotFound(turnoutId: turnoutId)
            }
            if let socketId = transition.b.socketId {
                // Find out all the sockets that this turnout can lead to, starting from "socketId"
                let socketIds = turnout.sockets(from: socketId)
                for socketId in socketIds {
                    // For each socket, find out all the transitions that can lead to the "to" socket
                    let trs = try transitions(from: turnout.socket(socketId), to: to)
                    if !trs.isEmpty {
                        // If such transitions are found, we can return now.
                        return [transition] + trs
                    }
                }
            }
            return []
        } else if let blockId = transition.b.block {
            if let toSocketId = to.socketId {
                // If the destination socket is specified, check that the transition
                // is actually using that socket id. Otherwise, it means that the transition
                // is entered the block from the "wrong" side and should be ignored.
                if blockId == to.block, transition.b.socketId == toSocketId {
                    return [transition]
                } else {
                    return []
                }
            } else {
                if blockId == to.block {
                    // If the transition ends at the block specified in `to` socket,
                    // returns the transition now.
                    return [transition]
                } else {
                    // If the block does not match the one in the transition,
                    // let's stop here the search. In the future, we might want
                    // to continue the search past this block until we find
                    // the one we want.
                    return []
                }
            }
        } else {
            throw LayoutError.invalidTransition(transition: transition)
        }
    }

    // This function returns the next block for the locomotive, reachable from the `fromBlock`
    // and that is either free or already reserved for the train. This function is used, for example,
    // by the TrainController in manual mode to follow the movement of the
    // train on the layout when it is manually driven by someone.
    func nextValidBlockForLocomotive(from blockWithLoco: Block, train _: Train) throws -> Block? {
        guard let trainInstance = blockWithLoco.trainInstance else {
            return nil
        }

        // Retrieve the next block in the direction of travel of the train
        guard let nextBlock = try ElementVisitor.blockAfter(block: blockWithLoco, direction: trainInstance.direction, layout: self) else {
            return nil
        }

        if nextBlock.reservation == nil {
            return nextBlock
        } else {
            return nil
        }
    }
}
