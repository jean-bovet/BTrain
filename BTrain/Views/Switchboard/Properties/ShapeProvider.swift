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

protocol ShapeProviding {
    
    var shapes: [Shape] { get }

    var selectedShape: Shape? { get }

    var connectableShapes: [ConnectableShape] { get }

    var draggableShapes: [DraggableShape] { get }

    var rotableShapes: [RotableShape] { get }

    var actionableShapes: [ActionableShape] { get }

    var trainShapes: [TrainShape] { get }

    var blockShapes: [BlockShape] { get }

    func append(_ shape: Shape)

    func remove(_ shape: Shape)
    
    func blockShape(for blockId: Identifier<Block>) -> BlockShape?
}

final class ShapeProvider: ShapeProviding {
    
    private (set) var shapes = [Shape]()

    private let layout: Layout
    private let observer: LayoutObserver
    private let context: ShapeContext
    
    var selectedShape: Shape? {
        return shapes.first(where: { $0.selected })
    }

    var connectableShapes: [ConnectableShape] {
        return shapes.compactMap({$0 as? ConnectableShape})
    }

    var draggableShapes: [DraggableShape] {
        return shapes.compactMap({$0 as? DraggableShape})
    }

    var rotableShapes: [RotableShape] {
        return shapes.compactMap({$0 as? RotableShape})
    }

    var actionableShapes: [ActionableShape] {
        return shapes.compactMap({$0 as? ActionableShape})
    }

    var trainShapes: [TrainShape] {
        return shapes.compactMap({$0 as? TrainShape})
    }

    var blockShapes: [BlockShape] {
        return shapes.compactMap({$0 as? BlockShape})
    }
    
    var turnoutShapes: [TurnoutShape] {
        return shapes.compactMap({$0 as? TurnoutShape})
    }
    
    init(layout: Layout, context: ShapeContext) {
        self.layout = layout
        self.observer = LayoutObserver(layout: layout)
        self.context = context
        
        observer.registerForTrainChange { trains in
            // Note: need to pass the `trains` parameter here because the layout.blocks
            // has not yet had the time to be updated
            self.updateShapes(trains: trains)
        }

        observer.registerForBlockChange { blocks in
            // Note: need to pass the `blocks` parameter here because the layout.blocks
            // has not yet had the time to be updated
            self.updateShapes(blocks: blocks.values.map { $0 as Block })
        }
        
        observer.registerForTurnoutChange { turnouts in
            // Note: need to pass the `turnouts` parameter here because the layout.turnouts
            // has not yet had the time to be updated
            self.updateShapes(turnouts: turnouts)
        }
        
        updateShapes()
    }
        
    func updateShapes(blocks: [Block]? = nil, turnouts: [Turnout]? = nil, trains: [Train]? = nil) {
        shapes.removeAll()

        if let blocks = blocks {
            updateBlocks(blocks: blocks)
        } else {
            updateBlocks(blocks: layout.blocks)
        }
        
        if let turnouts = turnouts {
            updateTurnouts(turnouts: turnouts)
        } else {
            updateTurnouts(turnouts: layout.turnouts)
        }
        
        for transition in layout.transitions {
            append(LinkShape(from: socketInstance(for: transition.a, shapes: self),
                             to: socketInstance(for: transition.b, shapes: self),
                             transition: transition, shapeContext: context))
        }
        
        if let trains = trains {
            updateTrains(trains: trains)
        } else {
            updateTrains(trains: layout.trains)
        }
    }
    
    func updateBlocks(blocks: [Block]) {
        for block in blocks {
            append(BlockShape(layout: layout, block: block, shapeContext: context))
        }
    }
    
    func updateTurnouts(turnouts: [Turnout]) {
        for turnout in turnouts {
            append(TurnoutShape(layout: layout, turnout: turnout, shapeContext: context))
        }
    }
    
    func updateTrains(trains: [Train]) {
        for train in trains {
            append(TrainShape(layout: layout, train: train, shapeProvider: self, shapeContext: context))
        }
    }
    
    func append(_ shape: Shape) {
        shapes.append(shape)
    }
    
    func remove(_ shape: Shape) {
        shapes.removeAll { $0.identifier == shape.identifier }
    }
    
    func blockShape(for blockId: Identifier<Block>) -> BlockShape? {
        return shapes
            .compactMap({ $0 as? BlockShape })
            .filter({ $0.block.id == blockId })
            .first
    }
    
    func socketInstance(for socket: Socket, shapes: ShapeProviding) -> ConnectorSocketInstance {
        guard let socketId = socket.socketId else {
            fatalError("SocketId must be specified for \(socket)")
        }
        
        if let shape = shape(for: socket, shapes: shapes) {
            return ConnectorSocketInstance(shape: shape, socketId: socketId)
        } else {
            fatalError("Unable to find a shape for socket \(socket)")
        }
    }
    
    func shape(for socket: Socket, shapes: ShapeProviding) -> ConnectableShape? {
        return shapes.connectableShapes.first { shape in
            if let blockId = socket.block {
                if let blockShape = shape as? BlockShape {
                    return blockShape.block.id == blockId
                }
            } else if let turnoutId = socket.turnout {
                if let turnoutShape = shape as? TurnoutShape {
                    return turnoutShape.turnout.id == turnoutId
                }
            } else {
                fatalError("Socket must have either its block or turnout defined")
            }
            return false
        }
    }

}
