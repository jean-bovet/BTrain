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

// A path consists of an array of elements.
typealias GraphPath = [GraphPathElement]

// Each element is a `node` with specified exit and enter sockets.
// A starting element only has an exit socket while the last
// element in the path only has an enter socket.
struct GraphPathElement: Equatable, CustomStringConvertible {
        
    let node: GraphNode
    let entrySocket: SocketId?
    let exitSocket: SocketId?

    var description: String {
        var text = ""
        if let enterSocket = entrySocket {
            text += "\(enterSocket):"
        }
        text += node.identifier
        if let exitSocket = exitSocket {
            text += ":\(exitSocket)"
        }
        return text
    }
    
    // Returns true if this element is the same as the other element, taking into account the fact that the entry or exit socket can be nil.
    // The following rules are used:
    // - Both element must refer to the same node identifier
    // - If this element's entrySocket is not nil, it must correspond to the other element's entrySocket. Otherwise, the entrySocket is ignored.
    // - If this element's exitSocket is not nil, it must correspond to the other element's exitSocket. Otherwise, the exitSocket is ignored.
    func isSame(as other: GraphPathElement) -> Bool {
        guard node.identifier == other.node.identifier else {
            return false
        }
        
        if let entrySocket = entrySocket, entrySocket != other.entrySocket {
            return false
        }
        
        if let exitSocket = exitSocket, exitSocket != other.exitSocket {
            return false
        }

        return true
    }
    
    static func starting(_ node: GraphNode, _ exitSocket: SocketId) -> GraphPathElement {
        .init(node: node, entrySocket: nil, exitSocket: exitSocket)
    }
    
    static func ending(_ node: GraphNode, _ entrySocket: SocketId?) -> GraphPathElement {
        .init(node: node, entrySocket: entrySocket, exitSocket: nil)
    }
    
    static func between(_ node: GraphNode, _ entrySocket: SocketId, _ exitSocket: SocketId) -> GraphPathElement {
        .init(node: node, entrySocket: entrySocket, exitSocket: exitSocket)
    }
    
    static func == (lhs: GraphPathElement, rhs: GraphPathElement) -> Bool {
        return lhs.node.identifier == rhs.node.identifier && lhs.entrySocket == rhs.entrySocket && lhs.exitSocket == rhs.exitSocket
    }
    
}
