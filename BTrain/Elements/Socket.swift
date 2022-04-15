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

// A socket identifies the "side" of an element. Two sockets
// are linked together with a transition.
struct Socket: Codable, Equatable, CustomStringConvertible {
    
    // The block this socket refers to, or nil if not a block
    let block: Identifier<Block>?
    
    // The turnout this socket refers to, or nil if not a turnout
    let turnout: Identifier<Turnout>?
    
    // The socket ID of the block or turnout it is referring to,
    // or nil if any socket of the turnout or block can be used.
    let socketId: Int?
        
    var description: String {
        if let block = block {
            if let socketId = socketId {
                return "Socket[block \(block), socket \(socketId)]"
            } else {
                return "Socket[block \(block), any socket]"
            }
        } else if let turnout = turnout {
            if let socketId = socketId {
                return "Socket[turnout \(turnout), socket \(socketId)]"
            } else {
                return "Socket[turnout \(turnout), any socket]"
            }
        } else {
            let msg = "Orphaned socket!"
            assertionFailure(msg)
            return msg
        }
    }

    static func block(_ id: Identifier<Block>) -> Socket {
        return Socket(block: id, turnout: nil, socketId: nil)
    }

    static func block(_ id: Identifier<Block>, socketId: Int?) -> Socket {
        return Socket(block: id, turnout: nil, socketId: socketId)
    }

    static func turnout(_ id: Identifier<Turnout>, socketId: Int?) -> Socket {
        return Socket(block: nil, turnout: id, socketId: socketId)
    }

    // Returns true if this socket contains the specified socket "s".
    // A socket that has no specified socketId can actually match
    // more specific sockets, for example:
    // Socket(turnout1, socket: 0) is contained in Socket(turnout1, socket: nil)
    func contains(other: Socket) -> Bool {
        if let block = block, block == other.block {
            return contains(otherSocketId: other.socketId)
        } else if let turnout = turnout, turnout == other.turnout {
            return contains(otherSocketId: other.socketId)
        } else {
            return false
        }        
    }
    
    func contains(otherSocketId: Int?) -> Bool {
        if let socketId = socketId {
            if let otherSocketId = otherSocketId {
                return socketId == otherSocketId
            } else {
                // Any socket is valid
                return true
            }
        } else {
            // Any socket is valid
            return true
        }
    }
}
    
