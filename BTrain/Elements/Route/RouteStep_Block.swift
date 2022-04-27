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

final class RouteStep_Block: RouteStep, ObservableObject {
    // The block identifier
    var blockId: Identifier<Block>

    // The number of seconds a train will wait in that block
    // If nil, the block waitingTime is used instead.
    var waitingTime: TimeInterval?
    
    override var description: String {
        return "\(blockId):\(direction)"
    }

    // The direction of travel of the train within that block
    var direction: Direction {
        get {
            return exitSocket?.socketId == Block.nextSocket ? .next : .previous
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

    convenience init(_ blockId: Identifier<Block>, _ direction: Direction, _ waitingTime: TimeInterval? = nil) {
        self.init(UUID().uuidString, blockId, direction, waitingTime)
    }

    convenience init(_ block: Block, _ direction: Direction, _ waitingTime: TimeInterval? = nil) {
        self.init(UUID().uuidString, block.id, direction, waitingTime)
    }

    init(_ id: String, _ blockId: Identifier<Block>, _ direction: Direction, _ waitingTime: TimeInterval? = nil) {
        self.blockId = blockId
        super.init(id: id)
        self.direction = direction
        self.waitingTime = waitingTime
    }
    
    init(_ id: String, _ blockId: Identifier<Block>, entrySocket: Socket?, exitSocket: Socket?, _ waitingTime: TimeInterval? = nil) {
        self.blockId = blockId
        super.init(id: id)
        self.entrySocket = entrySocket
        self.exitSocket = exitSocket
        self.waitingTime = waitingTime
    }

    enum CodingKeys: CodingKey {
      case blockId, waitingTime
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        blockId = try container.decode(Identifier<Block>.self, forKey: CodingKeys.blockId)
        waitingTime = try container.decodeIfPresent(TimeInterval.self, forKey: CodingKeys.waitingTime)
        try super.init(from: decoder)
    }
        
    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(blockId, forKey: CodingKeys.blockId)
        try container.encode(waitingTime, forKey: CodingKeys.waitingTime)
        try super.encode(to: encoder)
    }

}

