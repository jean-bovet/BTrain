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

// A turnout has three or more sockets. A socket is the input (or output)
// of the turnout and is used to link to another turnout or a block.
// Each turnout type has different sockets which are represented here:
//
// Single Left
//                    ╱ 2
//                   ╱
//         0 ───────■── 1
//
// Single Right
//
//         0 ───────■── 1
//                   ╲
//                    ╲ 2
//    Double-slip
//            2
//             ╲
//              ╲
//        0 ─────╳───── 1
//                ╲
//                 ╲
//                  3
//
//    Threeway        ╱ 3
//                   ╱
//         0 ───────■── 1
//                   ╲
//                    ╲ 2
extension Turnout {
    
    var socket0: Socket {
        return Socket.turnout(id, socketId: 0)
    }

    var socket1: Socket {
        return Socket.turnout(id, socketId: 1)
    }

    var socket2: Socket {
        return Socket.turnout(id, socketId: 2)
    }

    var socket3: Socket {
        precondition(category == .doubleSlip || category == .doubleSlip2 || category == .threeWay, "Invalid turnout category \(category) for socket3")
        return Socket.turnout(id, socketId: 3)
    }

    var allSockets: [Socket] {
        switch(category) {
        case .singleLeft, .singleRight:
            return [socket0, socket1, socket2]
        case .threeWay, .doubleSlip, .doubleSlip2:
            return [socket0, socket1, socket2, socket3]
        }
    }
    
    func socketName(_ socketId: Int) -> String {
        switch(category) {
        case .singleLeft:
            switch(socketId) {
            case 0:
                return "straight (enter)"
            case 1:
                return "straight (exit)"
            case 2:
                return "branch left"
            default:
                return ""
            }
        case .singleRight:
            switch(socketId) {
            case 0:
                return "straight (enter)"
            case 1:
                return "straight (exit)"
            case 2:
                return "branch right"
            default:
                return ""
            }

        case .threeWay:
            switch(socketId) {
            case 0:
                return "straight (enter)"
            case 1:
                return "straight (exit)"
            case 2:
                return "branch right"
            case 3:
                return "branch left"
            default:
                return ""
            }

        case .doubleSlip:
            switch(socketId) {
            case 0:
                return "branch01 (enter)"
            case 1:
                return "branch01 (exit)"
            case 2:
                return "branch23 (enter)"
            case 3:
                return "branch23 (exit)"
            default:
                return ""
            }
            
        case .doubleSlip2:
            switch(socketId) {
            case 0:
                return "branch01 (enter)"
            case 1:
                return "branch01 (exit)"
            case 2:
                return "branch23 (enter)"
            case 3:
                return "branch23 (exit)"
            default:
                return ""
            }
        }
    }
    
    func socket(_ socketId: Int) -> Socket {
        precondition(socketId <= 3, "Invalid socketId \(socketId)")
        return Socket.turnout(id, socketId: socketId)
    }
    
    // Returns all the sockets reachable from the specified socketId
    // Depending on the type of turnout, certain sockets are reachable.
    func sockets(from socketId: Int) -> [Int] {
        switch(category) {
        case .singleLeft, .singleRight:
            switch(socketId) {
            case 0:
                return [1, 2]
            case 1, 2:
                return [0]
            default:
                return []
            }

        case .doubleSlip:
            switch(socketId) {
            case 0:
                return [1, 3]
            case 1:
                return [0, 2]
            case 2:
                return [1, 3]
            case 3:
                return [0, 2]
            default:
                return []
            }

        case .doubleSlip2:
            switch(socketId) {
            case 0:
                return [1, 3]
            case 1:
                return [0, 2]
            case 2:
                return [1, 3]
            case 3:
                return [0, 2]
            default:
                return []
            }

        case .threeWay:
            switch(socketId) {
            case 0:
                return [1, 2, 3]
            case 1, 2, 3:
                return [0]
            default:
                return []
            }

        }
    }
    
}
