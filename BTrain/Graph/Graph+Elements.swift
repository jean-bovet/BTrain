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

extension Block: Node {
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

extension Turnout: Node {
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
    func edge(from: Node, socketId: SocketId) -> Edge? {
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
    
    func node(for elementId: GraphElementId) -> Node? {
        if let block = block(for: Identifier<Block>(uuid: elementId)) {
            return block
        } else if let turnout = turnout(for: Identifier<Turnout>(uuid: elementId)) {
            return turnout
        } else {
            return nil
        }
    }
        
}
