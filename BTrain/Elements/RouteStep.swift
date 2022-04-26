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

// A step of the route
struct RouteStep: Codable, Equatable, Identifiable, CustomStringConvertible {
    let id: String
    
    // The block identifier
    var blockId: Identifier<Block>?
    
    // The direction of travel of the train within that block
    var direction: Direction? {
        get {
            if blockId != nil {
                return exitSocket?.socketId == Block.nextSocket ? .next : .previous
            } else {
                assertionFailure("It is an error to request the direction for a step that does not refer to a block")
                return nil
            }
        }
        set {
            if let blockId = blockId {
                if newValue == .next {
                    exitSocket = Socket.block(blockId, socketId: 1)
                    entrySocket = Socket.block(blockId, socketId: 0)
                } else {
                    exitSocket = Socket.block(blockId, socketId: 0)
                    entrySocket = Socket.block(blockId, socketId: 1)
                }
            } else {
                assertionFailure("It is an error to set the direction of a step that does not refer to a block")
            }
        }
    }
    
    var turnoutId: Identifier<Turnout>?
    
    // The number of seconds a train will wait in that block
    // If nil, the block waitingTime is used instead.
    var waitingTime: TimeInterval?
    
    // Returns the socket where the train will exit
    // the block represented by this step, taking
    // into account the direction of travel of the train.
    var exitSocket: Socket?
    
    // Returns the socket where the train will enter
    // the block represented by this step, taking
    // into account the direction of travel of the train.
    var entrySocket: Socket?

    var description: String {
        if let blockId = blockId {
            return "\(blockId):\(direction!)"
        } else if let turnoutId = turnoutId {
            return "\(turnoutId):(\(entrySocket!.socketId!)>\(exitSocket!.socketId!))"
        } else {
            return "Invalid state because no block nor turnout is defined"
        }
    }

    func entrySocketOrThrow() throws -> Socket {
        guard let entrySocket = entrySocket else {
            throw LayoutError.entrySocketNotFound(step: self)
        }
        return entrySocket
    }
    
    func entrySocketId() throws -> Int {
        let entrySocket = try entrySocketOrThrow()
        guard let socketId = entrySocket.socketId else {
            throw LayoutError.socketIdNotFound(socket: entrySocket)
        }
        
        return socketId
    }

    func exitSocketOrThrow() throws -> Socket {
        guard let exitSocket = exitSocket else {
            throw LayoutError.exitSocketNotFound(step: self)
        }

        return exitSocket
    }
    
    func exitSocketId() throws -> Int {
        let exitSocket = try exitSocketOrThrow()
        guard let socketId = exitSocket.socketId else {
            throw LayoutError.socketIdNotFound(socket: exitSocket)
        }
        
        return socketId
    }

    init(_ blockId: Identifier<Block>, _ direction: Direction, _ waitingTime: TimeInterval? = nil) {
        self.init(UUID().uuidString, blockId, direction, waitingTime)
    }

    init(_ block: Block, _ direction: Direction, _ waitingTime: TimeInterval? = nil) {
        self.init(UUID().uuidString, block.id, direction, waitingTime)
    }

    init(_ id: String, _ blockId: Identifier<Block>, _ direction: Direction, _ waitingTime: TimeInterval? = nil) {
        self.id = id
        self.blockId = blockId
        self.direction = direction
        self.waitingTime = waitingTime
    }
    
    init(_ turnoutId: Identifier<Turnout>, _ fromSocket: Socket, _ toSocket: Socket) {
        self.id = UUID().uuidString
        self.turnoutId = turnoutId
        self.entrySocket = fromSocket
        self.exitSocket = toSocket
    }

    // This function returns true if this step is the same as the other step,
    // considering only the blockId and direction.
    func same(_ other: RouteStep) -> Bool {
        return blockId == other.blockId && direction == other.direction
    }
}
