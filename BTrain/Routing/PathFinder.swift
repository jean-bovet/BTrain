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

// This class finds a possible route (or path) from one block
// to another (or to any station), making sure to avoid any reserved
// block and block already taken. There is no guaranteed that the
// path will be the shortest.
final class PathFinder {
    
    enum PathError: Error {
        case overflow
    }

    // The path returned from this class after the algorithm is run
    struct Path {
        let steps: [Route.Step]
        let context: Context
    }
        
    // This class is used to keep track of the various parameters during analysis
    final class Context {
        // Train associated with this path
        let train: Train?

        // The destination or nil if any station block can be chosen
        let destination: Destination?
        
        // The maximum number of blocks in the path before
        // it overflows and the algorithm ends the analysis.
        // This is to avoid situation in which the algorithm
        // takes too long to return.
        let overflow: Int

        // Settings for the algorithm
        let settings: Settings

        // The list of steps defining this path
        let steps: [Route.Step]

        // The list of visited steps (block+direction),
        // used to ensure the algorithm does not
        // re-use a block and ends up in an infinite loop.
        let visitedSteps: [Route.Step]
        
        var path: Path {
            return Path(steps: steps, context: self)
        }
        
        init(train: Train?, destination: Destination?, overflow: Int, settings: Settings, steps: [Route.Step] = [], visitedSteps: [Route.Step] = []) {
            self.train = train
            self.destination = destination
            self.overflow = overflow
            self.settings = settings
            self.steps = steps
            self.visitedSteps = visitedSteps
        }
        
        func hasVisited(_ step: Route.Step) -> Bool {
            if settings.avoidAlreadyVisitedBlocks {
                return visitedSteps.contains { $0.same(step) }
            } else {
                return false
            }
        }

        var isOverflowing: Bool {
            return steps.count >= overflow
        }
        
        func appending(_ step: Route.Step) -> Context {
            return .init(train: train, destination: destination, overflow: overflow, settings: settings, steps: steps + [step], visitedSteps: visitedSteps)
        }
        
        func visiting(_ step: Route.Step) -> Context {
            return .init(train: train, destination: destination, overflow: overflow, settings: settings, steps: steps, visitedSteps: visitedSteps + [step])
        }

        func print(_ msg: String) {
            if settings.verbose {
                BTLogger.debug(" \(msg)")
            }
        }
    }

    struct Settings {
        // True to generate a route at random, false otherwise.
        let random: Bool
            
        // Search behavior when encountering a reserved block.
        enum ReservedBlockBehavior {
            // Avoid all reserved blocks (that is, avoid any block
            // that is reserved for another train).
            case avoidReserved
            
            // Ignore all reserved blocks (that is,
            // take them into account even if they are
            // reserved for another train).
            case ignoreReserved
            
            // Avoid the first reserved block encountered,
            // then ignore all the others reserved blocks.
            case avoidFirstReservedBlock
        }
        
        let reservedBlockBehavior: ReservedBlockBehavior
                
        var consideringStoppingAtSiding = false
        
        var includeTurnouts = false
        
        var ignoreDisabledElements = false
        
        // True if the first block that is found must match the destination.
        var firstBlockShouldMatchDestination = false
        
        var avoidAlreadyVisitedBlocks = true
        
        let verbose: Bool
    }

    let layout: Layout
    
    typealias TurnoutSocketSelectionOverride = (_ turnout:Turnout, _ socketsId: [Int], _ context: Context) -> Int?
    
    // Optional override block to inject behavior when a turnout is processed
    // during the path search. Used by unit tests only.
    var turnoutSocketSelectionOverride: TurnoutSocketSelectionOverride?
    
    init(layout: Layout) {
        self.layout = layout
    }
        
    func path(trainId: Identifier<Train>?, from block: Block, destination: Destination? = nil, direction: Direction, settings: Settings, generatedPathCallback: ((Path) -> Void)? = nil) throws -> Path? {
        let numberOfPaths: Int
        if destination != nil && settings.random {
            // If a destination block is specified and the path is choosen at random,
            // try to generate 10 paths and pick the shortest one.
            numberOfPaths = 10
        } else {
            // Otherwise, return the first path choosen.
            numberOfPaths = 1
        }
        
        let train = layout.train(for: trainId)
        
        // Note: until we have a proper algorithm that finds the shortest path in a single pass,
        // we will generate a few paths and pick the shortest one (depending on the `numberOfPaths`).
        var smallestPath: Path?
        let overflow = (layout.turnouts.count + layout.blocks.count) * 4
        for _ in 1...numberOfPaths {
            let context = Context(train: train, destination: destination, overflow: overflow, settings: settings, steps: [Route.Step(block.id, direction)])
            
            if let path = try findPath(from: block, direction: direction, context: context) {
                generatedPathCallback?(path)
                if smallestPath == nil {
                    smallestPath = path
                } else if let sp = smallestPath, path.steps.count < sp.steps.count {
                    smallestPath = path
                }
            }
        }
        return smallestPath
    }
    
    // MARK: -- Recursive functions
    
    private func findPath(from block: Block, direction: Direction, context: Context) throws -> Path? {
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
            return nil
        }
        
        // Remember this step in case we find it again during our analysis
        let newContext = context.visiting(step)

        // Find out all the transitions out of this block `next` or `previous` socket,
        // depending on the direction of travel of the train
        let from = direction == .next ? block.next : block.previous
        if let transition = try layout.transition(from: from) {
            assert(transition.a.block == block.id)
            if let path = try findPath(from: transition, context: newContext) {
                return path
            }
        }
        return nil
    }
    
    private func findPath(from turnout: Turnout, fromSocketId: Int, context: Context) throws -> Path? {
        guard !context.isOverflowing else {
            throw PathError.overflow
        }
        
        // Find out all the sockets accessible from the `fromSocketId`.
        var nextSocketIds = socketIds(turnout: turnout, socketId: fromSocketId, context: context)
        if context.settings.random {
            nextSocketIds.shuffle()
        }
        context.print("Evaluating possible sockets \(nextSocketIds) from \(turnout):\(fromSocketId)")
        
        // Iterate over all the sockets
        // TODO: return all possible paths to the destination from here?
        for id in nextSocketIds {
            let nextSocket = turnout.socket(id)
            if let transition = try layout.transition(from: nextSocket) {
                assert(transition.a.turnout == turnout.id)

                let newContext: Context
                if context.settings.includeTurnouts {
                    newContext = context.appending(Route.Step(turnout.id, Socket.turnout(turnout.id, socketId: fromSocketId), nextSocket))
                } else {
                    newContext = context
                }

                // Drill down this transition to see if it leads to a valid path
                if let path = try findPath(from: transition, context: newContext) {
                    return path
                } else {
                    if context.settings.includeTurnouts {
                        context.print("Backtracking \(turnout.name) and socket \(id) and removing it")
                    }
                }
            }
        }
        return nil
    }

    private func findPath(from transition: ITransition, context: Context) throws -> Path? {
        guard !context.isOverflowing else {
            throw PathError.overflow
        }

        if let nextBlockId = transition.b.block {
            // The transition ends up in a block, let's find out the direction of travel of the train within that block
            let nextBlockDirection: Direction
            if transition.b.socketId == Block.previousSocket {
                nextBlockDirection = .next
            } else {
                nextBlockDirection = .previous
            }
            
            // Find out if the next block is allowed to be used for that train
            if let train = context.train, train.blocksToAvoid.contains(where: {$0.blockId == nextBlockId }) {
                context.print("The next block \(nextBlockId) is marked as to be avoided by train \(train.name), backtracking")
                return nil
            }
            
            // Find out if the next block is already reserved
            guard let nextBlock = layout.block(for: nextBlockId) else {
                throw LayoutError.blockNotFound(blockId: nextBlockId)
            }
            
            if !nextBlock.enabled && !context.settings.ignoreDisabledElements  {
                context.print("The next block \(nextBlock) is disabled, backtracking")
                return nil
            } else if let reserved = nextBlock.reserved, reserved.trainId != context.train?.id {
                // The next block is reserved for another train, determine what to do.
                switch context.settings.reservedBlockBehavior {
                case .avoidReserved:
                    context.print("The next block \(nextBlock) is reserved for \(nextBlock.reserved!), backtracking")
                    return nil

                case .avoidFirstReservedBlock:
                    // Count the number of blocks that the path contains so far.
                    // Note: remove one block because we don't take into account the first block which is the starting block
                    let numberOfBlocks = context.steps.dropFirst().filter { $0.blockId != nil }.count
                    if numberOfBlocks == 0 {
                        context.print("The next block \(nextBlock) is reserved for \(nextBlock.reserved!), backtracking")
                        return nil
                    } else {
                        context.print("The next block \(nextBlock) is reserved for \(nextBlock.reserved!) but will be ignored because it is the first block")
                    }
                    
                case .ignoreReserved:
                    context.print("The next block \(nextBlock) is reserved for \(nextBlock.reserved!) but will be ignored")
                }
            }
            
            // Add this block to the path
            let newContext = context.appending(Route.Step(nextBlock.id, nextBlockDirection))
            
            // Return early if the block is a station,
            // because we have reached the end of the path
            if let destination = context.destination {
                if let toDirection = destination.direction {
                    if nextBlock.id == destination.blockId && nextBlockDirection == toDirection {
                        context.print("Reached the destination block \(destination.blockId) with desired direction of \(toDirection)")
                        return newContext.path
                    } else if context.settings.firstBlockShouldMatchDestination {
                        return nil
                    }
                } else {
                    if nextBlock.id == destination.blockId {
                        context.print("Reached the destination block \(destination.blockId)")
                        return newContext.path
                    } else if context.settings.firstBlockShouldMatchDestination {
                        return nil
                    }
                }
            } else if nextBlock.category == .station {
                context.print("Reached a station at block \(nextBlock)")
                return newContext.path
            } else if nextBlock.category == .sidingNext || nextBlock.category == .sidingPrevious {
                context.print("Reached a siding at block \(nextBlock)")
                if context.settings.consideringStoppingAtSiding {
                    return newContext.path
                } else {
                    return nil
                }
            }
                        
            // If the block is not a station, let's continue recursively
            if let path = try findPath(from: nextBlock, direction: nextBlockDirection, context: newContext) {
                return path
            } else {
                // If there is no path out of this block, we need to backtrack one block
                // and start again with another transitions.
                context.print("Backtracking \(nextBlock) and removing it")
            }
        } else if let nextTurnoutId = transition.b.turnout {
            // The transition ends up in a turnout
            guard let nextTurnout = layout.turnout(for: nextTurnoutId) else {
                throw LayoutError.turnoutNotFound(turnoutId: nextTurnoutId)
            }
            
            if !nextTurnout.enabled && !context.settings.ignoreDisabledElements  {
                context.print("The next turnout \(nextTurnout) is disabled, backtracking")
                return nil
            }
            
            if let reserved = nextTurnout.reserved, reserved.train != context.train?.id {
                // The next turnout is reserved for another train, determine what to do.
                switch context.settings.reservedBlockBehavior {
                case .avoidReserved:
                    context.print("The next turnout \(nextTurnout) is reserved for \(reserved.train), backtracking")
                    return nil
                    
                case .avoidFirstReservedBlock:
                    // Count the number of blocks that the path contains so far.
                    // Note: remove one block because we don't take into account the first block which is the starting block
                    let numberOfBlocks = context.steps.dropFirst().filter { $0.blockId != nil }.count
                    if numberOfBlocks == 1 {
                        context.print("The next turnout \(nextTurnout) is reserved for \(reserved.train) but will be ignored because it is before the first block")
                    } else {
                        context.print("The next turnout \(nextTurnout) is reserved for \(reserved.train), backtracking")
                        return nil
                    }
                    
                case .ignoreReserved:
                    context.print("The next turnout \(nextTurnout) is reserved for \(reserved.train) but will be ignored")
                }
            }
            
            // Find out if the next turnout is allowed to be used for that train
            if let train = context.train, train.turnoutsToAvoid.contains(where: {$0.turnoutId == nextTurnoutId }) {
                context.print("The next turnout \(nextTurnoutId) is marked as to be avoided by train \(train.name), backtracking")
                return nil
            }

            // Find a valid path out of that turnout
            if let path = try findPath(from: nextTurnout, fromSocketId: transition.b.socketId!, context: context) {
                return path
            }
        } else {
            assertionFailure("Unsupported scenario")
        }
        return nil
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
