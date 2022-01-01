// Copyright 2021 Jean Bovet
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
import Quartz

enum TextAlignment {
    case center
    case top
    case bottom
}

extension Shape {
        
    @discardableResult
    func drawText(ctx: CGContext, center: CGPoint, vAlignment: TextAlignment = .center, rotation: CGFloat = 0, text: String, color: CGColor, fontSize: CGFloat) -> CGSize {

        // You can use the Font Book app to find the name
        let fontName = "Helvetica" as CFString
        let font = CTFontCreateWithName(fontName, fontSize, nil)

        let attributes = [NSAttributedString.Key.font: font,
                          NSAttributedString.Key.foregroundColor: color] as [NSAttributedString.Key : Any]

        // Text
        let attributedString = NSAttributedString(string: text,
                                                  attributes: attributes)

        // Render
        let line = CTLineCreateWithAttributedString(attributedString)
        let stringRect = CTLineGetImageBounds(line, ctx)

        // Apply rotation angle
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: rotation)
        ctx.translateBy(x: -center.x, y: -center.y)

        // Flip the text
        let transform = CGAffineTransform.identity
            .translatedBy(x: 0.0, y: stringRect.height)
            .scaledBy(x: 1.0, y: -1.0)

        ctx.textMatrix = transform

        var p = CGPoint(x: center.x - stringRect.width / 2,
                        y: center.y + stringRect.height / 2)

        switch(vAlignment) {
        case .center:
            break
        case .top:
            p.y = p.y - stringRect.height/2
        case .bottom:
            p.y = p.y + stringRect.height/2
        }

        ctx.textPosition = p
        CTLineDraw(line, ctx)
        
        return stringRect.size
    }
    
}
