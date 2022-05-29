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

final class SwitchBoardRenderer {
 
    let provider: ShapeProvider
    let shapeContext: ShapeContext
    
    var ephemeralDragInfo: EphemeralDragInfo?
    
    var showAvailableSockets = false
    
    var color: CGColor {
        .init(red: 0, green: 0, blue: 1, alpha: 1)
    }

    init(provider: ShapeProvider, shapeContext: ShapeContext) {
        self.provider = provider
        self.shapeContext = shapeContext
    }
    
    func draw(context: CGContext) {
        for shape in provider.shapes.filter({$0.visible}) {
            context.with {
                shape.draw(ctx: context)
            }
        }
        
        // Highlight any free socket, either when asked to do so during the
        // dragging of a link (showAvailableSockets) or when a shape is selected
        // so the user can start creating a new link between shapes.
        for shape in provider.connectableShapes.filter({ $0.selected || showAvailableSockets }) {
            context.with {
                context.setFillColor(shapeContext.freeSocketColor)
                context.setStrokeColor(color)
                for socket in shape.freeSockets {
                    context.addPath(socket.shape)
                }
                context.drawPath(using: .fill)
            }
        }

        for shape in provider.rotableShapes.filter({ $0.selected }) {
            context.with {
                context.setFillColor(shapeContext.rotationHandleColor)
                context.addPath(shape.rotationHandle)
                context.fillPath()
            }
        }
        
        if let ephemeralDropPath = ephemeralDragInfo?.dropPath {
            context.with {
                context.setFillColor(shapeContext.dropPathColor.copy(alpha: 0.5)!)
                context.addPath(ephemeralDropPath)
                context.fillPath()
            }
        }

        if let ephemeralDragShape = ephemeralDragInfo?.shape {
            context.with {
                ephemeralDragShape.draw(ctx: context)
            }
        }

    }

}
