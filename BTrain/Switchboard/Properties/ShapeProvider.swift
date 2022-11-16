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
import Combine

final class ShapeProvider {
    
    private (set) var shapes = [Shape]()

    weak var layoutController: LayoutController?
    
    internal let layout: Layout
    private let observer: LayoutObserver
    internal let context: ShapeContext
    
    var selectedShape: Shape? {
        shapes.first(where: { $0.selected })
    }

    var connectableShapes: [ConnectableShape] {
        shapes.compactMap({ $0 as? ConnectableShape })
    }

    var draggableShapes: [DraggableShape] {
        shapes.compactMap({ $0 as? DraggableShape })
    }

    var rotableShapes: [RotableShape] {
        shapes.compactMap({ $0 as? RotableShape })
    }

    var actionableShapes: [ActionableShape] {
        shapes.compactMap({ $0 as? ActionableShape })
    }

    var dragOnTapProviders: [EphemeralDragProvider] {
        shapes.compactMap({ $0 as? EphemeralDragProvider })
    }

    var blockShapes: [BlockShape] {
        shapes.compactMap({ $0 as? BlockShape })
    }
    
    var turnoutShapes: [TurnoutShape] {
        shapes.compactMap({ $0 as? TurnoutShape })
    }
    
    var linkShapes: [LinkShape] {
        shapes.compactMap({ $0 as? LinkShape })
    }

    init(layout: Layout, context: ShapeContext) {
        self.layout = layout
        self.observer = LayoutObserver(layout: layout)
        self.context = context
        
        observer.registerForBlockChange { [weak self] blocks in
            // Note: need to pass the `blocks` parameter here because the layout.blocks
            // has not yet had the time to be updated
            self?.updateShapes(blocks: blocks )
        }
        
        observer.registerForTurnoutChange { [weak self] turnouts in
            // Note: need to pass the `turnouts` parameter here because the layout.turnouts
            // has not yet had the time to be updated
            self?.updateShapes(turnouts: turnouts)
        }
        
        observer.registerForTransitionChange { [weak self] transitions in
            self?.updateShapes(transitions: transitions)
        }
    }
        
    func updateShapes(blocks: [Block]? = nil, turnouts: [Turnout]? = nil, transitions: [Transition]? = nil) {
        shapes.removeAll()

        if let blocks = blocks {
            updateBlocks(blocks: blocks)
        } else {
            updateBlocks(blocks: layout.blocks.elements)
        }
        
        if let turnouts = turnouts {
            updateTurnouts(turnouts: turnouts)
        } else {
            updateTurnouts(turnouts: layout.turnouts.elements)
        }
        
        for transition in transitions ?? layout.transitions {
            do {
                append(LinkShape(from: try socketInstance(for: transition.a, shapes: self),
                                 to: try socketInstance(for: transition.b, shapes: self),
                                 transition: transition, shapeContext: context))
            } catch {
                BTLogger.error("Error updating the link shapes: \(error)")
            }
        }
        
        updateControlPointShapes(visible: false)
    }
    
    func removeControlPointShapes() {
        shapes.removeAll { $0 is ControlPointShape }
    }
    
    func updateBlocks(blocks: [Block]) {
        for block in blocks {
            append(BlockShape(layout: layout, block: block, shapeContext: context))
        }
    }
    
    func updateTurnouts(turnouts: [Turnout]) {
        for turnout in turnouts {
            append(TurnoutShape(layoutController: layoutController, layout: layout, turnout: turnout, shapeContext: context))
        }
    }
        
    func append(_ shape: Shape) {
        shapes.append(shape)
    }
    
    func remove(_ shape: Shape) {
        shapes.removeAll { $0.identifier == shape.identifier }
    }
    
    func blockShape(for blockId: Identifier<Block>) -> BlockShape? {
        shapes
                .compactMap({ $0 as? BlockShape })
                .filter({ $0.block.id == blockId })
                .first
    }
    
    func socketInstance(for socket: Socket, shapes: ShapeProvider) throws -> ConnectorSocketInstance {
        guard let socketId = socket.socketId else {
            throw LayoutError.socketIdNotFound(socket: socket)
        }
        
        if let shape = try shape(for: socket, shapes: shapes) {
            return ConnectorSocketInstance(shape: shape, socketId: socketId)
        } else {
            throw LayoutError.shapeNotFoundForSocket(socket: socket)
        }
    }
    
    func shape(for socket: Socket, shapes: ShapeProvider) throws -> ConnectableShape? {
        try shapes.connectableShapes.first { shape in
            if let blockId = socket.block {
                if let blockShape = shape as? BlockShape {
                    return blockShape.block.id == blockId
                }
            } else if let turnoutId = socket.turnout {
                if let turnoutShape = shape as? TurnoutShape {
                    return turnoutShape.turnout.id == turnoutId
                }
            } else {
                throw LayoutError.invalidSocket(socket: socket)
            }
            return false
        }
    }

}
