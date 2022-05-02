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

struct RouteStepBlock: RouteStep, Equatable, Codable, CustomStringConvertible {

    // TODO: equality should only be done with this ID for all the steps
    var id = UUID().uuidString
    
    // The block identifier
    var blockId: Identifier<Block>

    // The number of seconds a train will wait in that block
    // If nil, the block waitingTime is used instead.
    var waitingTime: TimeInterval?

    // TODO: technically could be nil, right? Should we only use the direction to be more clear?
    var exitSocket: Socket
    
    var entrySocket: Socket
    
    var description: String {
        return "\(blockId):\(direction)"
    }

    // The direction of travel of the train within that block
    var direction: Direction {
        get {
            return exitSocket.socketId == Block.nextSocket ? .next : .previous
        }
        set {
            if newValue == .next {
                exitSocket = Socket.block(blockId, socketId: 1)
                entrySocket = Socket.block(blockId, socketId: 0)
            } else {
                exitSocket = Socket.block(blockId, socketId: 0)
                entrySocket = Socket.block(blockId, socketId: 1)
            }
        }
    }

    init(_ block: Block, _ direction: Direction, _ waitingTime: TimeInterval? = nil) {
        self.init(block.id, direction, waitingTime)
    }

    init(_ blockId: Identifier<Block>, _ direction: Direction, _ waitingTime: TimeInterval? = nil) {
        self.blockId = blockId
        self.entrySocket = .block(blockId)
        self.exitSocket = .block(blockId)
        self.direction = direction
        self.waitingTime = waitingTime
    }
    
    init(_ blockId: Identifier<Block>, entrySocket: Socket, exitSocket: Socket, _ waitingTime: TimeInterval? = nil) {
        self.blockId = blockId
        self.entrySocket = entrySocket
        self.exitSocket = exitSocket
        self.waitingTime = waitingTime
    }

    func resolve(_ constraints: GraphPathFinderConstraints, _ context: GraphPathFinderContext) -> GraphPathElement? {
        // TODO: finish
        guard let lc = context as? LayoutPathFinder.LayoutContext else {
            return nil
        }
        let block = lc.layout.block(for: blockId)!
        return .init(node: block, entrySocket: entrySocket.socketId, exitSocket: exitSocket.socketId)
    }
}
