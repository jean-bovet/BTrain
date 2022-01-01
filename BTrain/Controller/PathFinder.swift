// Copyright 2021 Jean Bovet
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

// This class finds a possible route (or path) from one block
// to another (or to any station), making sure to avoid any reserved
// block and block already taken. There is no guaranteed that the
// path will be the shortest.
final class PathFinder {
    
    enum PathError: Error {
        case overflow
    }

    let layout: Layout
    
    typealias TurnoutSocketSelectionOverride = (_ turnout:Turnout, _ socketsId: [Int], _ context: Context) -> Int?
    
    // Optional override block to inject behavior when a turnout is processed
    // during the path search. Used by unit tests only.
    var turnoutSocketSelectionOverride: TurnoutSocketSelectionOverride?
    
    // Internal class used to keep track of the various parameters during analysis
    final class Context {
        // Train associated with this path
        let trainId: Identifier<Train>

        // The destination block or nil if any station block can be chosen
        let toBlock: IBlock?

        let random: Bool
        let reservedBlockLookAhead: Int
        let verbose: Bool
                
        // The maximum number of blocks in the path before
        // it overflows and the algorithm ends the analysis.
        // This is to avoid situation in which the algorithm
        // takes too long to return.
        let overflow: Int
        
        // The list of steps defining this path
        var steps = [Route.Step]()

        // The list of visited steps (block+direction),
        // used to ensure the algorithm does not
        // re-use a block and ends up in an infinite loop.
        var visitedSteps = [Route.Step]()
        
        init(trainId: Identifier<Train>, toBlock: IBlock?, random: Bool, reservedBlockLookAhead: Int, overflow: Int, verbose: Bool) {
            self.trainId = trainId
            self.toBlock = toBlock
            self.random = random
            
            self.reservedBlockLookAhead = reservedBlockLookAhead
            self.overflow = overflow
            self.verbose = verbose
        }
        
        func hasVisited(_ step: Route.Step) -> Bool {
            return visitedSteps.contains { $0.same(step) }
        }

        var isOverflowing: Bool {
            return steps.count >= overflow
        }
        
        func print(_ msg: String) {
            if verbose {
                BTLogger.debug(" \(msg)")
            }
        }
    }
    
    init(layout: Layout) {
        self.layout = layout
    }
        
    // The path returned from this class after the algorithm is run
    struct Path {
        let steps: [Route.Step]
        let context: Context
    }
        
    func path(trainId: Identifier<Train>, from block: IBlock, toBlock: IBlock? = nil, direction: Direction, reservedBlockLookAhead: Int, random: Bool = false, verbose: Bool = false) throws -> Path? {
        let context = Context(trainId: trainId, toBlock: toBlock, random: random, reservedBlockLookAhead: reservedBlockLookAhead, overflow: layout.blocks.count*2, verbose: verbose)
        context.steps.append(Route.Step(block.id, direction))
        
        if try findPath(from: block, direction: direction, context: context) {
            return Path(steps: context.steps, context: context)
        } else {
            return nil
        }
    }
    
    // MARK: -- Recursive functions
    
    private func findPath(from block: IBlock, direction: Direction, context: Context) throws -> Bool {
        guard !context.isOverflowing else {
            throw PathError.overflow
        }

        // Create the step represented by this block and direction
        let step = Route.Step(block.id, direction)
        
        // Return false if the step has been visited before,
        // indicating to the caller of this method that this block
        // is not a valid one to use.
        if context.hasVisited(step) {
            context.print("\(step) has been visited before, backtrack")
            return false
        }
        
        // Remember this step in case we find it again during our analysis
        context.visitedSteps.append(step)

        // Find out all the transitions out of this block `next` or `previous` socket,
        // depending on the direction of travel of the train
        let from = direction == .next ? block.next : block.previous
        var transitions = try layout.transitions(from: from, to: nil)
        context.print("Evaluating \(transitions.count) transitions from \(from)")
        if context.random {
            transitions.shuffle()
        }
        for transition in transitions {
            assert(transition.a.block == block.id)
            if try findPath(from: transition, context: context) {
                return true
            }
        }
        return false
    }
    
    private func findPath(from turnout: Turnout, fromSocketId: Int, context: Context) throws -> Bool {
        guard !context.isOverflowing else {
            throw PathError.overflow
        }
        
        // Find out all the sockets accessible from the `fromSocketId`.
        var nextSocketIds = socketIds(turnout: turnout, socketId: fromSocketId, context: context)
        if context.random {
            nextSocketIds.shuffle()
        }
        context.print("Evaluating possible sockets \(nextSocketIds) from \(turnout):\(fromSocketId)")

        // Iterate over all the sockets
        for id in nextSocketIds {
            let nextSocket = turnout.socket(id)
            let transitions = try layout.transitions(from: nextSocket, to: nil)
            context.print("Evaluating \(transitions.count) transitions from \(nextSocket)")
            for tr in transitions {
                assert(tr.a.turnout == turnout.id)
                // Drill down this transition to see if it leads
                // to a valid path
                if try findPath(from: tr, context: context) {
                    return true
                }
            }
        }
        return false
    }

    private func findPath(from transition: ITransition, context: Context) throws -> Bool {
        guard !context.isOverflowing else {
            throw PathError.overflow
        }

        if let nextBlockId = transition.b.block {
            // The transition ends up in a block,
            // let's find out the direction of travel of the train
            // within that block
            let nextBlockDirection: Direction
            if transition.b.socketId == Block.previousSocket {
                nextBlockDirection = .next
            } else {
                nextBlockDirection = .previous
            }
            
            // Find out if the next block is already reserved
            let nextBlock = layout.block(for: nextBlockId)!
            if let reserved = nextBlock.reserved, reserved.trainId != context.trainId {
                // The next block is reserved for another train, we cannot use it
                let stepCount = context.steps.count - 1 // Remove one block because we don't take into account the first block which is the starting block
                if stepCount < context.reservedBlockLookAhead {
                    context.print("The next block \(nextBlock) is reserved for \(nextBlock.reserved!), backtracking")
                    return false
                } else {
                    context.print("The next block \(nextBlock) is reserved for \(nextBlock.reserved!) but will be ignored because \(stepCount) steps is past the look ahead of \(context.reservedBlockLookAhead) block")
                }
            }
            
            // Add this block to the path
            context.steps.append(Route.Step(nextBlock.id, nextBlockDirection))
            
            // Return early if the block is a station,
            // because we have reached the end of the path
            if let toBlock = context.toBlock {
                if nextBlock.id == toBlock.id {
                    context.print("Reached the destination block \(toBlock)")
                    return true
                }
            } else if nextBlock.category == .station {
                context.print("Reached a station at block \(nextBlock)")
                return true
            }
            
            // If the block is not a station, let's continue recursively
            if try findPath(from: nextBlock, direction: nextBlockDirection, context: context) {
                return true
            } else {
                // If there is no path out of this block, we need to backtrack one block
                // and start again with another transitions.
                context.print("Backtracking \(nextBlock) and removing it")
                context.steps.removeLast()
            }
        } else if let nextTurnoutId = transition.b.turnout {
            // The transition ends up in a turnout
            let nextTurnout = layout.turnout(for: nextTurnoutId)!
            
            // Find a valid path out of that turnout
            if try findPath(from: nextTurnout, fromSocketId: transition.b.socketId!, context: context) {
                return true
            }
        } else {
            assertionFailure("Unsupported scenario")
        }
        return false
    }
    
    // This function takes a turnout and a `socket` it and returns all the sockets
    // accessible from `socket`. It uses the override block, in case it is defined,
    // to modify the results.
    private func socketIds(turnout: Turnout, socketId: Int, context: Context) -> [Int] {
        let nextSocketsId = turnout.sockets(from: socketId)
        
        // Let's give an opportunity to the override block, if defined,
        // to change the results.
        if let socketId = turnoutSocketSelectionOverride?(turnout, nextSocketsId, context) {
            return [socketId]
        } else {
            return nextSocketsId
        }
    }
    
}
