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

struct BlockGraphElementIdentifier: GraphElementIdentifier {
    let uuid: String
    let blockId: Identifier<Block>
    
    init(_ blockId: Identifier<Block>) {
        self.uuid = "b" + blockId.uuid
        self.blockId = blockId
    }
}

extension Block: GraphNode {
    var identifier: GraphElementIdentifier {
        BlockGraphElementIdentifier(id)
    }
     
    var weight: Double {
        return length ?? 0
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

extension Block {
    
    var elementDirectionNext: GraphPathElement {
        return .between(self, Block.previousSocket, Block.nextSocket)
    }
    
    var elementDirectionPrevious: GraphPathElement {
        return .between(self, Block.nextSocket, Block.previousSocket)
    }

}

struct TurnoutGraphElementIdentifier: GraphElementIdentifier {
    let uuid: String
    let turnoutId: Identifier<Turnout>
    init(_ turnoutId: Identifier<Turnout>) {
        self.uuid = "t" + turnoutId.uuid
        self.turnoutId = turnoutId
    }
}

extension Turnout: GraphNode {
    var identifier: GraphElementIdentifier {
        TurnoutGraphElementIdentifier(id)
    }
    
    var weight: Double {
        return length ?? 0
    }

    var sockets: [SocketId] {
        allSockets.compactMap { $0.socketId }
    }
    
    func reachableSockets(from socket: SocketId) -> [SocketId] {
        sockets(from: socket)
    }
    
}

struct TransitionGraphElementIdentifier: GraphElementIdentifier {
    let uuid: String
    let transitionId: Identifier<Transition>
    init(_ transitionId: Identifier<Transition>) {
        self.uuid = "tr" + transitionId.uuid
        self.transitionId = transitionId
    }
}

struct InvalidElementIdentifier: GraphElementIdentifier {
    var uuid: String = UUID().uuidString
}

extension ITransition {
    var identifier: GraphElementIdentifier {
        TransitionGraphElementIdentifier(id)
    }
    
    var fromNode: GraphElementIdentifier {
        if let block = a.block {
            return BlockGraphElementIdentifier(block)
        } else if let turnout = a.turnout {
            return TurnoutGraphElementIdentifier(turnout)
        } else {
            assertionFailure("Socket must specify a block or a turnout")
            return InvalidElementIdentifier()
        }
    }
    
    var fromNodeSocket: SocketId? {
        return a.socketId
    }
    
    var toNode: GraphElementIdentifier {
        if let block = b.block {
            return BlockGraphElementIdentifier(block)
        } else if let turnout = b.turnout {
            return TurnoutGraphElementIdentifier(turnout)
        } else {
            assertionFailure("Socket must specify a block or a turnout")
            return InvalidElementIdentifier()
        }
    }
    
    var toNodeSocket: SocketId? {
        return b.socketId
    }
    
}

extension Layout {
    
    func block(_ node: GraphNode) -> Block? {
        return block(node.identifier)
    }

    func block(_ identifier: GraphElementIdentifier) -> Block? {
        guard let blockIdentifier = identifier as? BlockGraphElementIdentifier else {
            return nil
        }
    
        return block(for: blockIdentifier.blockId)
    }

    func turnout(_ node: GraphNode) -> Turnout? {
        return turnout(node.identifier)
    }
    
    func turnout(_ identifier: GraphElementIdentifier) -> Turnout? {
        guard let turnoutIdentifier = identifier as? TurnoutGraphElementIdentifier else {
            return nil
        }
        return turnout(for: turnoutIdentifier.turnoutId)
    }
}

extension Layout: Graph {
    func edge(from: GraphNode, socketId: SocketId) -> GraphEdge? {
        let socket: Socket
        if let block = block(from) {
            socket = Socket.block(block.id, socketId: socketId)
        } else if let turnout = turnout(from) {
            socket = Socket.turnout(turnout.id, socketId: socketId)
        } else {
            return nil
        }

        return try? transition(from: socket)
    }
    
    func node(for elementId: GraphElementIdentifier) -> GraphNode? {
        if let block = block(elementId) {
            return block
        } else if let turnout = turnout(elementId) {
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
 
    func shortestPath(for train: Train, from: (Block, Direction), to: (Block, Direction), pathFinder: GraphPathFinding, constraints: GraphPathFinderConstraints) throws -> GraphPath? {
        let fromElement = from.1 == .next ? from.0.elementDirectionNext:from.0.elementDirectionPrevious
        let toElement = to.1 == .next ? to.0.elementDirectionNext:to.0.elementDirectionPrevious

        return try pathFinder.shortestPath(graph: self, from: fromElement, to: toElement, constraints: constraints)
    }
    
}

extension Array where Element == GraphPathElement {
    
    var toBlockSteps: [RouteItem] {
        return self.toSteps.compactMap { step in
            if case .block(_) = step {
                return step
            } else {
                return nil
            }
        }
    }
    
    var toSteps: [RouteItem] {
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
                return .block(RouteStep_Block(block, direction))
            } else if let turnout = element.node as? Turnout {
                guard let entrySocket = element.entrySocket else {
                    return nil
                }
                guard let exitSocket = element.exitSocket else {
                    return nil
                }
                return .turnout(RouteStep_Turnout(turnout.id, turnout.socket(entrySocket), turnout.socket(exitSocket)))
            } else {
                return nil
            }
        }
    }

}
