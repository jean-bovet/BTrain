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

import CoreGraphics
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
        let visibleShapes = provider.shapes.filter(\.visible)

        if provider.context.showStationBackground {
            drawStationsBackground(context: context, visibleShapes: visibleShapes)
        }

        for shape in visibleShapes {
            context.with {
                shape.draw(ctx: context)
            }
        }

        // Draw dotted line between the custom control points
        if shapeContext.editing {
            for shape in provider.linkShapes {
                context.with {
                    context.setStrokeColor(.black.copy(alpha: 0.5)!)
                    if let cp1 = shape.controlPoint1 {
                        context.move(to: shape.from.position)
                        context.addLine(to: cp1.position)
                        if let cp2 = shape.controlPoint2 {
                            context.addLine(to: cp2.position)
                            context.addLine(to: shape.to.position)
                        }
                    }
                    context.strokePath()
                }
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

        for shape in provider.rotableShapes.filter(\.selected) {
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

    private func drawStationsBackground(context: CGContext, visibleShapes: [Shape]) {
        for station in provider.layout.stations.elements {
            let blockIds = station.elements.compactMap(\.blockId)

            var bounds = CGRect.zero
            for shape in visibleShapes {
                if let blockShape = shape as? BlockShape, blockIds.contains(blockShape.block.id) {
                    if bounds == .zero {
                        bounds = blockShape.boundsIncludingLabels
                    } else {
                        bounds = bounds.union(blockShape.boundsIncludingLabels)
                    }
                }
            }
            if bounds != .zero {
                bounds = bounds.insetBy(dx: -20, dy: -20)
                context.with {
                    context.setFillColor(shapeContext.backgroundStationBlockColor.copy(alpha: 0.2)!)
                    context.addPath(.init(roundedRect: bounds, cornerWidth: 10, cornerHeight: 10, transform: nil))
                    context.drawPath(using: .fill)
                }
            }
        }
    }
}
