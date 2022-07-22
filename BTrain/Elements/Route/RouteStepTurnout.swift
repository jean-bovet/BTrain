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

struct RouteStepTurnout: RouteStep, Equatable, Codable {
    
    static func ==(lhs: RouteStepTurnout, rhs: RouteStepTurnout) -> Bool {
        lhs.id == rhs.id
    }

    var id = UUID().uuidString

    var turnoutId: Identifier<Turnout>
    
    var exitSocket: Socket
    
    var entrySocket: Socket

    var description: String {
        "\(turnoutId):(\(entrySocket.socketId!)>\(exitSocket.socketId!))"
    }
    
    init(_ turnoutId: Identifier<Turnout>, _ fromSocket: Socket, _ toSocket: Socket) {
        self.turnoutId = turnoutId
        self.entrySocket = fromSocket
        self.exitSocket = toSocket
    }
    
    func resolve(_ constraints: GraphPathFinderConstraints, _ context: GraphPathFinderContext) -> [GraphPathElement]? {
        guard let lc = context as? LayoutPathFinder.LayoutContext else {
            return nil
        }
        guard let turnout = lc.layout?.turnout(for: turnoutId) else {
            return nil
        }
        return [GraphPathElement(node: turnout, entrySocket: entrySocket.socketId, exitSocket: exitSocket.socketId)]

    }

}
