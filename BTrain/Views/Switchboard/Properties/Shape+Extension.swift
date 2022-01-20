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
import Quartz

enum VTextAlignment {
    case center
    case top
    case bottom
    
    var inverse: VTextAlignment {
        switch(self) {
        case .center:
            return .center
        case .top:
            return .bottom
        case .bottom:
            return .top
        }
    }
}

enum HTextAlignment {
    case center
    case left
    case right
    var inverse: HTextAlignment {
        switch(self) {
        case .center:
            return .center
        case .left:
            return .right
        case .right:
            return .left
        }
    }
}

extension Shape {
        
    func prepareText(ctx: CGContext, text: String, color: CGColor, fontSize: CGFloat) -> (CTLine, CGRect) {
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

        return (line, stringRect)
    }
    
    @discardableResult
    func drawText(ctx: CGContext, at location: CGPoint,
                  vAlignment: VTextAlignment = .center,
                  hAlignment: HTextAlignment = .center,
                  rotation: CGFloat = 0,
                  text: String, color: CGColor, fontSize: CGFloat,
                  borderColor: CGColor? = nil, backgroundColor: CGColor? = nil) -> CGSize {

        let (line, stringRect) = prepareText(ctx: ctx, text: text, color: color, fontSize: fontSize)
        
        // Apply rotation angle
        ctx.translateBy(x: location.x, y: location.y)
        ctx.rotate(by: rotation)
        ctx.translateBy(x: -location.x, y: -location.y)

        // Flip the text
        let transform = CGAffineTransform.identity
            .translatedBy(x: 0.0, y: stringRect.height)
            .scaledBy(x: 1.0, y: -1.0)

        ctx.textMatrix = transform

        var p = location
        
        switch(vAlignment) {
        case .center:
            p.y = p.y - stringRect.height/2
        case .top:
            p.y = p.y + stringRect.height
        case .bottom:
            p.y = p.y + 0
        }

        switch(hAlignment) {
        case .center:
            p.x = p.x - stringRect.width/2
        case .left:
            p.x = p.x + 0
        case .right:
            p.x = p.x - stringRect.width
        }
                
        if let borderColor = borderColor, let backgroundColor = backgroundColor {
            let sr = CGRect(x: p.x, y: p.y - stringRect.height, width: stringRect.width + 2, height: stringRect.height).insetBy(dx: -3, dy: -3)

            ctx.setFillColor(backgroundColor)
            ctx.fill(sr)
            
            ctx.setStrokeColor(borderColor)
            ctx.stroke(sr)
        }
        
        ctx.textPosition = p
        CTLineDraw(line, ctx)
                
        return stringRect.size
    }
    
}
