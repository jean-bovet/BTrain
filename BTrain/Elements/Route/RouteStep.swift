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
class RouteStep: Codable, Equatable, Hashable, Identifiable, CustomStringConvertible {
    
    static func == (lhs: RouteStep, rhs: RouteStep) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let id: String
        
    var description: String {
        fatalError("This step must be instantiated from one of its concrete subclass")
    }

    // Returns the socket where the train will exit
    // the block represented by this step, taking
    // into account the direction of travel of the train.
    var exitSocket: Socket?
    
    // Returns the socket where the train will enter
    // the block represented by this step, taking
    // into account the direction of travel of the train.
    var entrySocket: Socket?
    
    init(id: String) {
        self.id = id
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
    
    enum CodingKeys: CodingKey {
      case id, entrySocket, exitSocket
    }
        
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: CodingKeys.id)
        self.entrySocket = try container.decodeIfPresent(Socket.self, forKey: CodingKeys.entrySocket)
        self.exitSocket = try container.decodeIfPresent(Socket.self, forKey: CodingKeys.exitSocket)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(entrySocket, forKey: CodingKeys.entrySocket)
        try container.encode(exitSocket, forKey: CodingKeys.exitSocket)
    }

}

struct RouteStep_v1: Codable {
    let id: String
    
    var blockId: Identifier<Block>?
        
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

}

extension Array where Element == RouteStep_v1 {
    
    var toRouteSteps: [RouteStep] {
        self.map { routeStepv1 in
            routeStepv1.toRouteStep
        }
    }
}

extension RouteStep_v1 {
    
    var toRouteStep: RouteStep {
        if let blockId = blockId {
            return RouteStep_Block(id, blockId, entrySocket: entrySocket, exitSocket: exitSocket, waitingTime)
        } else if let turnoutId = turnoutId {
            return RouteStep_Turnout(turnoutId, entrySocket!, exitSocket!)
        } else {
            fatalError("Unknown step configuration: \(self)")
        }
    }
}
