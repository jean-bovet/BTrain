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

/// Shape representing a ``ControlPoint``
final class ControlPointShape: Shape, DraggableShape {
        
    let controlPoint: ControlPoint
    let shapeContext: ShapeContext

    var identifier = UUID().uuidString
    
    /// This shape is only visible during editing
    var visible: Bool = false
    
    var selected: Bool = false
    
    let width = 6.0
    
    var bounds: CGRect {
        path.boundingBox
    }

    var center: CGPoint {
        get {
            controlPoint.position
        }
        set {
            controlPoint.position = newValue
        }
    }

    var path: CGPath {
        let path = CGMutablePath()
        path.addRect(.init(x: center.x - width/2, y: center.y - width/2, width: width, height: width))
        return path
    }

    internal init(controlPoint: ControlPoint, shapeContext: ShapeContext) {
        self.controlPoint = controlPoint
        self.shapeContext = shapeContext
    }
    
    func draw(ctx: CGContext) {
        ctx.saveGState()

        ctx.addPath(path)
        ctx.setStrokeColor(shapeContext.pathColor(false, train: false))
        ctx.setLineWidth(shapeContext.trackWidth)
        ctx.drawPath(using: .fill)
        
        ctx.restoreGState()
    }
    
    func inside(_ point: CGPoint) -> Bool {
        return bounds.contains(point)
    }
    
    
}
