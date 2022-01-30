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

// This class is used to visit the elements of the layout in a specific direction,
// receiving a callback for each element visited (transition, turnout and block).
final class ElementVisitor {
    let layout: Layout
    
    init(layout: Layout) {
        self.layout = layout
    }
    
    struct ElementInfo {
        var transition: ITransition? = nil
        var turnout: Turnout? = nil
        var block: Block? = nil
        
        // Direction in which the visitor algorithm is traversing the block
        var direction: Direction? = nil
        
        // Index of the block the visitor algorithm is visiting
        var index: Int
    }
    
    enum VisitorCallbackResult {
        case stop
        case `continue`
    }
    
    typealias VisitorCallback = (ElementInfo) throws -> VisitorCallbackResult
    
    func visit(fromBlockId: Identifier<Block>, direction: Direction, callback: VisitorCallback) throws {
        guard let block = layout.block(for: fromBlockId) else {
            throw LayoutError.blockNotFound(blockId: fromBlockId)
        }
        guard try callback(.init(block: block, direction: direction, index: 0)) == .continue else {
            return
        }
        let fromSocket = direction == .next ? block.next : block.previous
        try visit(fromSocket: fromSocket, index: 1, callback: callback)
    }
    
    private func visit(fromSocket: Socket, index: Int, callback: VisitorCallback) throws {
        let transitions = try layout.transitions(from: fromSocket, to: nil)
        if transitions.isEmpty {
            return
        } else if transitions.count > 1 {
            throw LayoutError.alwaysOneAndOnlyOneTransition
        } else {
            let transition = transitions[0]
            
            guard try callback(.init(transition: transition, index: index)) == .continue else {
                return
            }

            // Transitions are always ordered with a being "from" and b "to" - see self.transitions() method
            guard let toSocketId = transition.b.socketId else {
                throw LayoutError.socketIdNotFound(socket: transition.b)
            }
            
            if let blockId = transition.b.block {
                // Transition is leading to a block
                guard let block = layout.block(for: blockId) else {
                    throw LayoutError.blockNotFound(blockId: blockId)
                }

                let direction: Direction = toSocketId == block.previous.socketId ? .next : .previous
                guard try callback(.init(block: block, direction: direction, index: index)) == .continue else {
                    return
                }

                // Recursively call this method again to continue the job in the next element
                if direction == .next {
                    try visit(fromSocket: block.next, index: index+1, callback: callback)
                } else {
                    try visit(fromSocket: block.previous, index: index+1, callback: callback)
                }
            } else if let turnoutId = transition.b.turnout {
                // Transition is leading to a turnout
                guard let turnout = layout.turnout(for: turnoutId) else {
                    throw LayoutError.turnoutNotFound(turnoutId: turnoutId)
                }

                guard try callback(.init(turnout: turnout, index: index)) == .continue else {
                    return
                }
                                    
                // Find out the exit socket of the turnout given its state
                guard let socketId = turnout.socketId(fromSocketId: toSocketId, withState: turnout.state) else {
                    // No error because it can happen that a turnout is configured for another route
                    return
                }
                
                // Recursively call this method again to continue the job in the next element
                try visit(fromSocket: turnout.socket(socketId), index: index+1, callback: callback)
            }
        }
    }
}
