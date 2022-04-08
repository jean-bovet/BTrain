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

extension Block: GraphNode {
    var identifier: GraphElementId {
        id.uuid
    }
    
    var sockets: [SocketId] {
        allSockets.compactMap { $0.socketId }
    }
    
    func reachableSockets(from socket: SocketId) -> [SocketId] {
        if socket == Block.previousSocket {
            return [Block.nextSocket]
        } else {
            return [Block.previousSocket]
        }
    }
        
}

extension Turnout: GraphNode {
    var identifier: GraphElementId {
        id.uuid
    }
    
    var sockets: [SocketId] {
        allSockets.compactMap { $0.socketId }
    }
    
    func reachableSockets(from socket: SocketId) -> [SocketId] {
        sockets(from: socket)
    }
    
}

extension ITransition {
    var identifier: GraphElementId {
        id.uuid
    }
    
    var fromNode: GraphElementId {
        if let block = a.block {
            return block.uuid
        } else if let turnout = a.turnout {
            return turnout.uuid
        } else {
            fatalError("Socket must specify a block or a turnout")
        }
    }
    
    var fromNodeSocket: SocketId? {
        return a.socketId
    }
    
    var toNode: GraphElementId {
        if let block = b.block {
            return block.uuid
        } else if let turnout = b.turnout {
            return turnout.uuid
        } else {
            fatalError("Socket must specify a block or a turnout")
        }
    }
    
    var toNodeSocket: SocketId? {
        return b.socketId
    }
    
}

extension Layout: Graph {
    func edge(from: GraphNode, socketId: SocketId) -> GraphEdge? {
        let socket: Socket
        if let block = block(for: Identifier<Block>(uuid: from.identifier)) {
            socket = Socket.block(block.id, socketId: socketId)
        } else if let turnout = turnout(for: Identifier<Turnout>(uuid: from.identifier)) {
            socket = Socket.turnout(turnout.id, socketId: socketId)
        } else {
            return nil
        }

        return try? transition(from: socket)
    }
    
    func node(for elementId: GraphElementId) -> GraphNode? {
        if let block = block(for: Identifier<Block>(uuid: elementId)) {
            return block
        } else if let turnout = turnout(for: Identifier<Turnout>(uuid: elementId)) {
            return turnout
        } else {
            return nil
        }
    }
        
}

extension Layout {
        
    var pathFinderOverflowLimit: Int {
        return (turnouts.count + blocks.count) * 4
    }
        
    func path(for train: Train, from: (Block, Direction), to: (Block, Direction?)?, pathFinder: GraphPathFinding, constraints: GraphPathFinderConstraints) -> GraphPath? {
        // Note: when direction is `next`, it means we are leaving the starting element from its `nextSocket`
        let fromElement = GraphPathElement.starting(from.0, from.1 == .next ? Block.nextSocket : Block.previousSocket)
        let toElement: GraphPathElement?
        if let to = to {
            // The destination direction is optional. If missing, the algorithm is going to try to reach the
            // destination block from both sides.
            if let direction = to.1 {
                // Note: when direction is `next`, it means we are entering the last block from its `previousSocket`
                toElement = .ending(to.0, direction == .next ? Block.previousSocket : Block.nextSocket)
            } else {
                toElement = .ending(to.0, nil)
            }
        } else {
            toElement = nil
        }
        return pathFinder.path(graph: self, from: fromElement, to: toElement, constraints: constraints)
    }
        
    func graphPath(from steps: [Route.Step]) throws -> GraphPath {
        return try steps.compactMap { step in
            if let blockId = step.blockId {
                guard let block = self.block(for: blockId) else {
                    throw LayoutError.blockNotFound(blockId: blockId)
                }
                return GraphPathElement(node: block, entrySocket: try step.entrySocketId(), exitSocket: try step.exitSocketId())
            } else if let turnoutId = step.turnoutId {
                guard let turnout = self.turnout(for: turnoutId) else {
                    throw LayoutError.turnoutNotFound(turnoutId: turnoutId)
                }
                return GraphPathElement(node: turnout, entrySocket: try step.entrySocketId(), exitSocket: try step.exitSocketId())
            } else {
                return nil
            }
        }
    }

}

extension Array where Element == GraphPathElement {
    
    var toBlockSteps: [Route.Step] {
        return self.compactMap { element in
            if let block = element.node as? Block {
                let direction: Direction
                if let entrySocket = element.entrySocket {
                    direction = entrySocket == Block.previousSocket ? .next : .previous
                } else if let exitSocket = element.exitSocket {
                    direction = exitSocket == Block.nextSocket ? .next : .previous
                } else {
                    return nil
                }
                return Route.Step(block, direction)
            } else {
                return nil
            }
        }
    }
    
    var toSteps: [Route.Step] {
        return self.compactMap { element in
            if let block = element.node as? Block {
                let direction: Direction
                if let entrySocket = element.entrySocket {
                    direction = entrySocket == Block.previousSocket ? .next : .previous
                } else if let exitSocket = element.exitSocket {
                    direction = exitSocket == Block.nextSocket ? .next : .previous
                } else {
                    return nil
                }
                return Route.Step(block, direction)
            } else if let turnout = element.node as? Turnout {
                guard let entrySocket = element.entrySocket else {
                    return nil
                }
                guard let exitSocket = element.exitSocket else {
                    return nil
                }
                return Route.Step(turnout.id, turnout.socket(entrySocket), turnout.socket(exitSocket))
            } else {
                return nil
            }
        }
    }

}
