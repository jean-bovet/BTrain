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
import CoreGraphics

/// Displays a text label
struct BlockShape_TextLabel: BlockShapeLabel {
            
    let ctx: CGContext
    let text: String
    let shapeContext: ShapeContext
    let size: CGSize
    let borderColor: CGColor

    var hidden: Bool = false

    internal init(ctx: CGContext, text: String, borderColor: CGColor, shapeContext: ShapeContext, hidden: Bool = false) {
        self.ctx = ctx
        self.text = text
        self.borderColor = borderColor
        self.shapeContext = shapeContext
        self.hidden = hidden
        
        let (_, textRect) = ctx.prepareText(text: text, color: shapeContext.color, fontSize: shapeContext.fontSize)
        self.size = textRect.size
    }
    
    func draw(at anchor: CGPoint, rotation: CGFloat, rotationCenter: CGPoint) -> BlockShapeLabelPath? {
        guard !hidden else {
            return nil
        }
        
        ctx.with {
            ctx.drawText(at: anchor, vAlignment: .center, hAlignment: .left, rotation: rotation,
                         text: text, color: shapeContext.color, fontSize: shapeContext.fontSize, borderColor: borderColor, backgroundColor: shapeContext.backgroundLabelColor)
        }

        var transform = CGAffineTransform.identity.rotation(by: rotation, around: anchor)

        transform = transform
            .translatedBy(x: anchor.x, y: anchor.y)
            .scaledBy(x: 1.0, y: -1.0)
            .translatedBy(x: -anchor.x, y: -anchor.y)

        transform = transform.translatedBy(x: 0, y: -size.height/2)

        let r = CGRect(x: anchor.x, y: anchor.y, width: size.width, height: size.height)
        return BlockShapeLabelPath(path: CGPath(rect: r, transform: nil),
                                   transform: transform)
    }
    
}

