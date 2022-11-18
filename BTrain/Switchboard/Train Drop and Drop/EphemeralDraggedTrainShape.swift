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

import AppKit
import Foundation

/// Implementation of the ephemeral draggable shape for a train. It uses an image of the train being dragged.
final class EphemeralDraggedTrainShape: EphemeralDraggableShape {
    let trainId: Identifier<Train>

    let image: NSImage

    var center: CGPoint

    var identifier = UUID().uuidString

    var visible: Bool = true

    var selected: Bool = false

    var bounds: CGRect {
        .init(origin: CGPoint(x: center.x - image.size.width / 2, y: center.y - image.size.height / 2), size: image.size)
    }

    var dragInfo: EphemeralDragInfo? {
        SwitchBoardTrainDragInfo(trainId: trainId, shape: self)
    }

    init(trainId: Identifier<Train>, image: NSImage, center: CGPoint) {
        self.trainId = trainId
        self.image = image
        self.center = center
    }

    func draw(ctx: CGContext) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }

        ctx.draw(cgImage, in: bounds)
    }

    func inside(_ point: CGPoint) -> Bool {
        bounds.contains(point)
    }

    func droppableShape(_ shapes: [Shape], at location: CGPoint) -> Shape? {
        shapes.first { shape in
            guard shape.inside(location) else {
                return false
            }

            guard let blockShape = shape as? BlockShape else {
                return false
            }

            return blockShape.block.reservation == nil && blockShape.block.trainInstance == nil && blockShape.block.enabled
        }
    }
}
