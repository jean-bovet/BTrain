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
        add(Transition(id: Layout.newIdentity(transitions), a: from, b: to))
    }
    
    func add(_ transition: Transition) {
        guard transitions.first(where: { $0.same(as: transition) }) == nil else {
            return
        }
        transitions.append(transition)
    }
    
    func remove(transitionID: Identifier<Transition>) {
        transitions.removeAll(where: { $0.id == transitionID })        
    }

    func transitions(from fromBlock: Identifier<Block>, to nextBlock: Identifier<Block>, direction: Direction) throws -> [ITransition] {
        guard let b1 = self.block(for: fromBlock) else {
            throw LayoutError.blockNotFound(blockId: fromBlock)
        }
        guard let b2 = self.block(for: nextBlock) else {
            throw LayoutError.blockNotFound(blockId: nextBlock)
        }
        return try transitions(from: b1, to: b2, direction: direction)
    }
    
    func transitions(from fromBlock: Block, to nextBlock: Block, direction: Direction) throws -> [ITransition] {
        if direction == .next {
            // If the train travels in the natural direction of the fromBlock,
            // returns all the transitions that starts at the "next" end
            // of the fromBlock.
            return try transitions(from: fromBlock.next, to: nextBlock.any)
        } else {
            // If the train travels in the opposite direction of the natural direction
            // of the fromBlock, returns all the transitions that starts at the "previous"
            // end of the fromBlock.
            return try transitions(from: fromBlock.previous, to: nextBlock.any)
        }
    }

    // Returns the transition from the specified socket. There is either no transition
    // or a single transition out of a socket.
    // An exception is thrown if more than one transition is found because this is an error.
    func transition(from: Socket) throws -> ITransition? {
        let candidates: [ITransition] = self.transitions.compactMap { transition in
            if transition.a.contains(other: from) {
                return transition
            } else if transition.b.contains(other: from) {
                // Returns the reverse of the transition so the code below
                // always assume from=a and to=b
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
    //┌─────────┐                     ┌─────────┐
    //│ Block 1 │────▶  Turnout  ────▶│ Block 2 │
    //└─────────┘                     └─────────┘
    func transitions(from: Socket, to: Socket) throws -> [ITransition] {
        // Find out all the transitions (candidates) that start or end with the "from" socket.
        // For example, a transition between a block and a turnout can be represented by:
        //┌─────────┐
        //│ Block 1 │b─────────a  Turnout
        //└─────────┘
        // Or:
        //┌─────────┐
        //│ Block 1 │a─────────b  Turnout
        //└─────────┘
        //The same between two blocks (or two turnouts):
        //┌─────────┐           ┌─────────┐
        //│ Block 1 │b─────────a│ Block 2 │
        //└─────────┘           └─────────┘
        // Or:
        //┌─────────┐           ┌─────────┐
        //│ Block 1 │a─────────b│ Block 2 │
        //└─────────┘           └─────────┘
        guard let transition = try self.transition(from: from) else {
            return []
        }
                                     
        if transition.b == to {
            // If the transition ends at the "to" socket, we can return it now.
            return [transition]
        } else if let turnoutId = transition.b.turnout {
            // If the transition ends at a turnout, iterate over all the sockets
            // until a transition to the `to` socket is found.
            guard let turnout = self.turnout(for: turnoutId) else {
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
        } else {
            fatalError("Unsupported configuration")
        }
    }

    func entryFeedback(from fromBlock: Block, to nextBlock: Block) throws -> (Feedback?, direction: Direction) {
        guard let direction = fromBlock.train?.direction else {
            throw LayoutError.trainNotFoundInBlock(blockId: fromBlock.id)
        }
        
        let transitions = try transitions(from: fromBlock, to: nextBlock, direction: direction)
        guard let lastTransition = transitions.last else {
            throw LayoutError.noTransition(fromBlockId: fromBlock.id, toBlockId: nextBlock.id)
        }
        
        // Determine if the train is moving in the "natural" direction
        // inside the next block, that is, entering from the "previous" side
        // (and exiting in the "next" side). This will help determine
        // which feedback to monitor on that next block.
        guard let blockId = lastTransition.b.block, blockId == nextBlock.id else {
            throw LayoutError.lastTransitionToBlock(transition: lastTransition.id, blockId: nextBlock.id)
        }
        
        let nextBlockDirectionOfTravel: Direction = lastTransition.b.socketId == Block.previousSocket ? .next : .previous

        // Now return the appropriate feedback depending on the direction
        // of travel of the train into the next block.
        let entryFeedbackId = nextBlock.entryFeedback(for: nextBlockDirectionOfTravel)
        let entryFeedback = self.feedback(for: entryFeedbackId)
        return (entryFeedback, nextBlockDirectionOfTravel)
    }

    // This function returns the next block for the locomotive, reachable from the `fromBlock`
    // and that is either free or already reserved for the train. This function is used, for example,
    // by the TrainController in manual mode to follow the movement of the
    // train on the layout when it is manually driven by someone.
    func nextBlock(from fromBlock: Block) -> Block? {
        guard let trainInstance = fromBlock.train else {
            return nil
        }
        
        var nextBlock: Block?
        let visitor = ElementVisitor(layout: self)
        try? visitor.visit(fromBlockId: fromBlock.id, direction: trainInstance.direction) { info in
            if let block = info.block, info.index > 0 {
                // TODO: check that the reservation is actually for the train wagons in front of the
                // locomotive and not for the occupied block (which would means the locomotive is looping back on itself)?
                if block.reserved == nil || block.reserved?.trainId == trainInstance.trainId {
                    nextBlock = block
                }
                return .stop
            }
            return .continue
        }
        
        return nextBlock
    }
}
