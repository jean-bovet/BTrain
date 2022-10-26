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
        a.socketId
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
        b.socketId
    }
    
}
