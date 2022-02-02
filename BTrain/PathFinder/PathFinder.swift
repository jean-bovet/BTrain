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

    let layout: Layout
    
    typealias TurnoutSocketSelectionOverride = (_ turnout:Turnout, _ socketsId: [Int], _ context: PathFinderContext) -> Int?
    
    // Optional override block to inject behavior when a turnout is processed
    // during the path search. Used by unit tests only.
    var turnoutSocketSelectionOverride: TurnoutSocketSelectionOverride?
    
    init(layout: Layout) {
        self.layout = layout
    }
        
    // The path returned from this class after the algorithm is run
    struct Path {
        let steps: [Route.Step]
        let context: PathFinderContext
    }
        
    func path(trainId: Identifier<Train>, from block: Block, destination: Destination? = nil, direction: Direction, settings: PathFinderSettings, generatedPathCallback: ((Path) -> Void)? = nil) throws -> Path? {
        let numberOfPaths: Int
        if destination != nil && settings.random {
            // If a destination block is specified and the path is choosen at random,
            // try to generate 10 paths and pick the shortest one.
            numberOfPaths = 10
        } else {
            // Otherwise, return the first path choosen.
            numberOfPaths = 1
        }
        
        guard let train = layout.train(for: trainId) else {
            throw LayoutError.trainNotFound(trainId: trainId)
        }
        
        // Note: until we have a proper algorithm that finds the shortest path in a single pass,
        // we will generate a few paths and pick the shortest one (depending on the `numberOfPaths`).
        var smallestPath: Path?
        for _ in 1...numberOfPaths {
            let context = PathFinderContext(train: train, destination: destination, overflow: layout.blockMap.count*2, settings: settings)
            context.steps.append(Route.Step(block.id, direction))
            
            if try findPath(from: block, direction: direction, context: context) {
                let path = Path(steps: context.steps, context: context)
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
    
    private func findPath(from block: Block, direction: Direction, context: PathFinderContext) throws -> Bool {
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
        if context.settings.random {
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
    
    private func findPath(from turnout: Turnout, fromSocketId: Int, context: PathFinderContext) throws -> Bool {
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

    private func findPath(from transition: ITransition, context: PathFinderContext) throws -> Bool {
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
            
            // Find out if the next block is allowed to be used for that train
            if context.train.blocksToAvoid.contains(where: {$0.blockId == nextBlockId }) {
                context.print("The next block \(nextBlockId) is marked as to be avoided by train \(context.train.name), backtracking")
                return false
            }
            
            // Find out if the next block is already reserved
            let nextBlock = layout.block(for: nextBlockId)!
            if !nextBlock.enabled  {
                context.print("The next block \(nextBlock) is disabled, backtracking")
                return false
            } else if let reserved = nextBlock.reserved, reserved.trainId != context.train.id {
                // The next block is reserved for another train, we cannot use it
                let stepCount = context.steps.count - 1 // Remove one block because we don't take into account the first block which is the starting block
                
                // Determine what to do when a reserved block is found
                switch(context.settings.reservedBlockBehavior) {
                case .avoidReserved:
                    context.print("The next block \(nextBlock) is reserved for \(nextBlock.reserved!), backtracking")
                    return false
                    
                case .avoidReservedUntil(numberOfSteps: let numberOfSteps):
                    if stepCount < numberOfSteps {
                        context.print("The next block \(nextBlock) is reserved for \(nextBlock.reserved!), backtracking")
                        return false
                    } else {
                        context.print("The next block \(nextBlock) is reserved for \(nextBlock.reserved!) but will be ignored because \(stepCount) steps is past the look ahead of \(numberOfSteps) blocks")
                    }
                }
            }
            
            // Add this block to the path
            context.steps.append(Route.Step(nextBlock.id, nextBlockDirection))
            
            // Return early if the block is a station,
            // because we have reached the end of the path
            if let destination = context.destination {
                if let toDirection = destination.direction {
                    if nextBlock.id == destination.blockId && nextBlockDirection == toDirection {
                        context.print("Reached the destination block \(destination.blockId) with desired direction of \(toDirection)")
                        return true
                    }
                } else {
                    if nextBlock.id == destination.blockId {
                        context.print("Reached the destination block \(destination.blockId)")
                        return true
                    }
                }
            } else if nextBlock.category == .station {
                context.print("Reached a station at block \(nextBlock)")
                return true
            } else if nextBlock.category == .sidingNext || nextBlock.category == .sidingPrevious {
                context.print("Reached a siding at block \(nextBlock)")
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
            
            // Find out if the next turnout is allowed to be used for that train
            if context.train.turnoutsToAvoid.contains(where: {$0.turnoutId == nextTurnoutId }) {
                context.print("The next turnout \(nextTurnoutId) is marked as to be avoided by train \(context.train.name), backtracking")
                return false
            }

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
    private func socketIds(turnout: Turnout, socketId: Int, context: PathFinderContext) -> [Int] {
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
