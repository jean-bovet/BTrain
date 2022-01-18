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

extension Block {
    
    // Returns the integer that indicates the "previous" socket
    static var previousSocket: Int {
        return 0
    }
    
    // Returns the integer that indicates the "next" socket
    static var nextSocket: Int {
        return 1
    }
    
    // Returns the socket from the "previous" side
    var previous: Socket {
        return Socket.block(id, socketId: Block.previousSocket)
    }

    // Returns the socket from the "next" side
    var next: Socket {
        return Socket.block(id, socketId: Block.nextSocket)
    }
    
    // Returns a socket that does not have any side indication,
    // which can be useful when we want to refer to "any socket
    // from block" in transitions calculation.
    var any: Socket {
        return Socket.block(id)
    }
    
    // Returns all the sockets
    var allSockets: [Socket] {
        switch(category) {
        case .station, .free:
            return [previous, next]
        case .sidingPrevious:
            return [next]
        case .sidingNext:
            return [previous]
        }
    }
    
    // Returns the name of the specific socket
    func socketName(_ socketId: Int) -> String {
        switch(socketId) {
        case 0:
            return "previous"
        case 1:
            return "next"
        default:
            return "?"
        }
    }

}
