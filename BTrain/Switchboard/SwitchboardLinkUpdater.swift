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

// This class handles removing or adding a transition based on the Switchboard
// specified LinkShape. It is invoked after the user dragged one of the end
// of the LinkShape in order to either remove or add a link between elements.
final class SwitchboardLinkUpdater {
    
    let layout: Layout
    let shapeProvider: ShapeProvider
    
    init(layout: Layout, shapes: ShapeProvider) {
        self.layout = layout
        self.shapeProvider = shapes
    }
    
    func updateTransitions(for linkShape: LinkShape) throws {
        let fromSocket = socket(from: linkShape.from.socket)
        let toSocket = socket(from: linkShape.to.socket)

        // Always remove the transition from the layout because a new one will be added
        if let transition = linkShape.transition {
            layout.transitions.elements.removeAll { $0.id == transition.id }
        }

        linkShape.selected = false

        if let fromSocket = fromSocket, let toSocket = toSocket {
            // Remove the shape and return now if the from and to socket are the same,
            // no transition is allowed in that case
            if fromSocket == toSocket {
                shapeProvider.remove(linkShape)
                return
            }
            
            // If both sockets are found, this means there is a link
            // established between two elements (two shapes).
            let t = Transition(id: LayoutIdentity.newIdentity(layout.transitions.elements, prefix: .transition), a: fromSocket, b: toSocket)
            
            // Assign the new transition to the shape
            linkShape.transition = t
            
            // Add the transition to the layout
            layout.add(t)
        } else {
            // The link is not fully connected, remove it from the layout
            shapeProvider.remove(linkShape)
        }
    }
        
    func socket(from socketInstance: ConnectorSocketInstance?) -> Socket? {
        guard let socketInstance = socketInstance else {
            return nil
        }

        let socketInstanceShape = shapeProvider.shapes.first { $0.identifier == socketInstance.shape.identifier }
        if let blockShape = socketInstanceShape as? BlockShape {
            return .block(blockShape.block.id, socketId: socketInstance.socketId)
        } else if let turnoutShape = socketInstanceShape as? TurnoutShape {
            return .turnout(turnoutShape.turnout.id, socketId: socketInstance.socketId)
        } else {
            return nil
        }
    }

}
