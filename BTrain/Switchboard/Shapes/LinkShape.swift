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

final class LinkShape: Shape, PluggableShape {
        
    let shapeContext: ShapeContext
    
    var identifier = UUID().uuidString
    
    var visible = true

    var selected = false
            
    var transition: Transition?
    var controlPoint1: ControlPoint?
    var controlPoint2: ControlPoint?

    let from = ConnectorPlug(id: 0)
    let to = ConnectorPlug(id: 1)
        
    var bounds: CGRect {
        path.boundingBoxOfPath
    }
    
    var path: CGPath {
        let path = CGMutablePath()
        path.move(to: from.position)
        path.addCurve(to: to.position,
                      control1: ctrlPoint1,
                      control2: ctrlPoint2)
        return path
    }
    
    /// Returns the point where the two lines, originating from the ``from`` and ``to`` connector cross. Nil if they don't cross each other.
    var intersection: CGPoint? {
        Line2D.linesCross(start1: from.position, end1: from.linePoint, start2: to.position, end2: to.linePoint)
    }
    
    /// Returns the first control point
    var ctrlPoint1: CGPoint {
        if let controlPoint1 = controlPoint1 {
            return controlPoint1.position
        } else if let p = intersection {
            return p
        } else {
            return from.control
        }
    }
    
    /// Returns the second control point
    var ctrlPoint2: CGPoint {
        if let controlPoint2 = controlPoint2 {
            return controlPoint2.position
        } else if let p = intersection {
            return p
        } else {
            return to.control
        }
    }

    var plugs: [ConnectorPlug] {
        [from, to]
    }

    var reserved: Bool {
        if let transition = transition {
            return transition.reserved != nil
        } else {
            // Note: during the switchboard editing, a LinkShape can exist without a transition
            // while the shape is being dragged on the screen.
            return false
        }
    }
    
    var occupied: Bool {
        if let transition = transition {
            return transition.train != nil
        } else {
            // Note: during the switchboard editing, a LinkShape can exist without a transition
            // while the shape is being dragged on the screen.
            return false
        }
    }

    init(from: ConnectorSocketInstance?, to: ConnectorSocketInstance?, transition: Transition?, shapeContext: ShapeContext) {
        self.from.socket = from
        self.to.socket = to
        self.transition = transition
        self.shapeContext = shapeContext
    }
        
    func draw(ctx: CGContext) {
        ctx.saveGState()

        ctx.addPath(path)
        ctx.setStrokeColor(shapeContext.pathColor(reserved, train: occupied))
        ctx.setLineWidth(shapeContext.trackWidth)
        ctx.drawPath(using: .stroke)
        
        ctx.restoreGState()
        
        if selected {
            for plug in plugs {
                ctx.addPath(plug.shape)
            }
            ctx.setFillColor(shapeContext.plugColor)
            ctx.setLineWidth(shapeContext.selectedTrackWidth)
            ctx.fillPath()
        }
    }
    
    func inside(_ point: CGPoint) -> Bool {
        // Create a new path that is wider than the one drawn on the screen
        // to allow the selection to happen more easily for the user.
        let widerPath = path.copy(strokingWithWidth: shapeContext.trackWidth, lineCap: .butt, lineJoin: .bevel, miterLimit: 0)
        return widerPath.contains(point)
    }
}
