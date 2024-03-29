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

/// Displays the train icon as a label
struct BlockShape_IconLabel: BlockShapeLabel {
    let ctx: CGContext
    let icon: NSImage
    let shapeContext: ShapeContext
    let size: CGSize

    var hidden: Bool = false

    let hAlignment = HTextAlignment.left

    internal init(ctx: CGContext, icon: NSImage, shapeContext: ShapeContext) {
        self.ctx = ctx
        self.icon = icon
        self.shapeContext = shapeContext

        let ratio = icon.size.width / icon.size.height
        let height = shapeContext.fontSize * 2
        let width = height * ratio
        size = .init(width: width, height: height)
    }

    func draw(at anchor: CGPoint, rotation: CGFloat, rotationCenter _: CGPoint) -> BlockShapeLabelPath? {
        guard !hidden else {
            return nil
        }

        guard let cgImage = icon.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        // Maintain rotation such that the icon is always on top or to the left
        var transform = CGAffineTransform.identity
            .rotation(by: rotation, around: anchor)

        // Flip the icon vertically
        transform = transform
            .translatedBy(x: anchor.x, y: anchor.y)
            .scaledBy(x: 1.0, y: -1.0)
            .translatedBy(x: -anchor.x, y: -anchor.y)

        // Apply translation
        switch hAlignment {
        case .center:
            transform = transform.translatedBy(x: -size.width / 2, y: 0)
        case .left:
            break
        case .right:
            transform = transform.translatedBy(x: size.width / 2, y: 0)
        }

        transform = transform.translatedBy(x: 0, y: -size.height / 2)

        ctx.with {
            ctx.concatenate(transform)
            ctx.draw(cgImage, in: CGRect(x: anchor.x, y: anchor.y, width: size.width, height: size.height))
        }

        return BlockShapeLabelPath(path: CGPath(rect: CGRect(x: anchor.x, y: anchor.y, width: size.width, height: size.height), transform: nil),
                                   transform: transform)
    }
}
