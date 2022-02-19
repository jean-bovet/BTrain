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

final class TurnoutShape: Shape, DraggableShape, ConnectableShape {
    let layout: Layout
    let turnout: Turnout
    let shapeContext: ShapeContext
    
    var identifier: String {
        return "turnout-\(turnout.id)"
    }
        
    var bounds: CGRect {
        return path.boundingBox
    }
            
    var center: CGPoint {
        get {
            return turnout.center
        }
        set {
            turnout.center = newValue
        }
    }
    
    var radius = 15.0
    
    var visible = true

    var selected = false
    
    var sockets: [ConnectorSocket] {
        return socketPoints.enumerated().map { (index, point) in
            // The control point is computed by extending the vector from
            // the center of the turnout to the socket point.
            let v = Vector2D(x: point.x-center.x, y: point.y-center.y)
            let vn = v.normalized
            let l = v.magnitude * 4
            let ctrlPoint = CGPoint(x: center.x + vn.x * l, y: center.y + vn.y * l)
            return ConnectorSocket.create(id: index, center: point, controlPoint: ctrlPoint)
        }
    }
    
    var freeSockets: [ConnectorSocket] {
        // Returns all the sockets that don't have any transitions coming out of them
        return sockets.filter { connectorSocket in
            let s = Socket.turnout(turnout.id, socketId: connectorSocket.id)
            return (try? layout.transition(from: s)) == nil
        }
    }
    
    var reserved: Identifier<Train>? {
        return turnout.reserved
    }
    
    func socketInstance(_ id: Int) -> ConnectorSocketInstance {
        return ConnectorSocketInstance(shape: self, socketId: id)
    }
    
    var socketPoints: [CGPoint] {
        let points: [CGPoint]
        switch(turnout.category) {
        case .singleLeft:
            points = [
                CGPoint(x: center.x-radius, y: center.y),
                CGPoint(x: center.x+radius, y: center.y),
                CGPoint(x: center.x+radius, y: center.y).rotate(by: -.pi/4, around: center)
            ]
            
        case .singleRight:
            points = [
                CGPoint(x: center.x-radius, y: center.y),
                CGPoint(x: center.x+radius, y: center.y),
                CGPoint(x: center.x+radius, y: center.y).rotate(by: .pi/4, around: center)
            ]
            
        case .doubleSlip:
            points = [
                CGPoint(x: center.x-radius, y: center.y),
                CGPoint(x: center.x+radius, y: center.y),
                CGPoint(x: center.x-radius, y: center.y).rotate(by: .pi/4, around: center),
                CGPoint(x: center.x+radius, y: center.y).rotate(by: .pi/4, around: center)
            ]
            
        case .doubleSlip2:
            points = [
                CGPoint(x: center.x-radius, y: center.y),
                CGPoint(x: center.x+radius, y: center.y),
                CGPoint(x: center.x-radius, y: center.y).rotate(by: .pi/4, around: center),
                CGPoint(x: center.x+radius, y: center.y).rotate(by: .pi/4, around: center)
            ]
            
        case .threeWay:
            points = [
                CGPoint(x: center.x-radius, y: center.y),
                CGPoint(x: center.x+radius, y: center.y),
                CGPoint(x: center.x+radius, y: center.y).rotate(by: .pi/4, around: center),
                CGPoint(x: center.x+radius, y: center.y).rotate(by: -.pi/4, around: center)
            ]
        }
        return points.map { $0.rotate(by: rotationAngle, around: center)}
    }
    
    var path: CGPath {
        let path = CGMutablePath()
        
        let sp = socketPoints
        
        switch(turnout.category) {
        case .singleLeft:
            path.move(to: sp[0])
            path.addLine(to: sp[1])

            path.move(to: center)
            path.addLine(to: sp[2])

        case .singleRight:
            path.move(to: sp[0])
            path.addLine(to: sp[1])

            path.move(to: center)
            path.addLine(to: sp[2])

        case .doubleSlip:
            path.move(to: sp[0])
            path.addLine(to: sp[1])

            path.move(to: sp[2])
            path.addLine(to: sp[3])

        case .doubleSlip2:
            path.move(to: sp[0])
            path.addLine(to: sp[1])

            path.move(to: sp[2])
            path.addLine(to: sp[3])

        case .threeWay:
            path.move(to: sp[0])
            path.addLine(to: sp[1])

            path.move(to: center)
            path.addLine(to: sp[2])

            path.move(to: center)
            path.addLine(to: sp[3])
        }

        return path
    }
    
    func activePath() -> CGPath {
        let path = CGMutablePath()
        
        let sp = socketPoints
        
        switch(turnout.category) {
        case .singleLeft, .singleRight:
            switch(turnout.state) {
            case .straight:
                path.move(to: sp[0])
                path.addLine(to: sp[1])
            case .branchLeft, .branchRight:
                path.move(to: sp[0])
                path.addLine(to: center)
                path.addLine(to: sp[2])
            default:
                break
            }

        case .doubleSlip:
            switch(turnout.state) {
            case .straight:
                // Note: only show one straight path
                path.move(to: sp[0])
                path.addLine(to: sp[1])
                
//                path.move(to: sp[2])
//                path.addLine(to: sp[3])
            case .branch:
                // Note: only show one branch
                path.move(to: sp[0])
                path.addLine(to: center)
                path.addLine(to: sp[3])
                
//                path.move(to: sp[2])
//                path.addLine(to: center)
//                path.addLine(to: sp[1])
            default:
                break
            }

        case .doubleSlip2:
            switch(turnout.state) {
            case .straight01:
                path.move(to: sp[0])
                path.addLine(to: sp[1])
            case .straight23:
                path.move(to: sp[2])
                path.addLine(to: sp[3])
            case .branch03:
                path.move(to: sp[0])
                path.addLine(to: center)
                path.addLine(to: sp[3])
            case .branch21:
                path.move(to: sp[2])
                path.addLine(to: center)
                path.addLine(to: sp[1])
            default:
                break
            }

        case .threeWay:
            switch(turnout.state) {
            case .straight:
                path.move(to: sp[0])
                path.addLine(to: sp[1])
            case .branchLeft:
                path.move(to: sp[0])
                path.addLine(to: center)
                path.addLine(to: sp[3])
            case .branchRight:
                path.move(to: sp[0])
                path.addLine(to: center)
                path.addLine(to: sp[2])
            default:
                break
            }
        }

        return path
    }

    func endCaps(_ radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for p in socketPoints {
            path.addEllipse(in: CGRect(origin: p, size: CGSize(width: radius, height: radius)).offsetBy(dx: -radius/2, dy: -radius/2))
        }
        return path
    }
    
    var outlinePath: CGPath {
        let rect = CGRect(origin: CGPoint(x: center.x-radius, y: center.y-radius), size: CGSize(width: 2*radius, height: 2*radius))
        return CGPath(ellipseIn: rect, transform: nil)
    }
    
    convenience init(layout: Layout, turnout: Turnout, center: CGPoint, rotationAngle: CGFloat = 0, shapeContext: ShapeContext) {
        self.init(layout: layout, turnout: turnout, shapeContext: shapeContext)
        self.turnout.center = center
        self.turnout.rotationAngle = rotationAngle
    }
    
    init(layout: Layout, turnout: Turnout, shapeContext: ShapeContext) {
        self.layout = layout
        self.turnout = turnout
        self.shapeContext = shapeContext
    }
    
    func draw(ctx: CGContext) {
        ctx.with {
            let lineWidth = selected ? shapeContext.selectedTrackWidth : shapeContext.trackWidth
            if !turnout.enabled {
                ctx.setLineDash(phase: 0, lengths: [3, 3])
            }

            ctx.setStrokeColor(shapeContext.color.copy(alpha: 0.5)!)
            ctx.setLineWidth(lineWidth)
            ctx.addPath(path)
            ctx.drawPath(using: .stroke)
            
            ctx.setStrokeColor(reserved != nil ? shapeContext.reservedColor : shapeContext.color)
            ctx.setLineWidth(shapeContext.trackWidth)
            ctx.addPath(activePath())
            ctx.drawPath(using: .stroke)
        }
                
        if shapeContext.showTurnoutName {
            ctx.with {
                drawLabel(ctx: ctx, label: turnout.name, at: center.translatedBy(x: 0, y: -radius), color: shapeContext.color, fontSize: shapeContext.fontSize)
            }
        }
    }
            
    @discardableResult
    func drawLabel(ctx: CGContext, label: String, at location: CGPoint, color: CGColor, fontSize: CGFloat) -> CGSize {
        let textCenter = location.rotate(by: rotationAngle, around: rotationCenter)

        // Always displays the text facing downwards so it is easer to read
        let angle = rotationAngle.truncatingRemainder(dividingBy: 2 * .pi)
        if abs(angle) <= .pi/2 || abs(angle) >= 2 * .pi*3/4 {
            return ctx.drawText(at: textCenter, vAlignment: .bottom, hAlignment: .center, rotation: angle,
                            text: label, color: color, fontSize: fontSize)
        } else {
            return ctx.drawText(at: textCenter, vAlignment: .top, hAlignment: .center, rotation: angle + .pi,
                            text: label, color: color, fontSize: fontSize)
        }
    }

    func inside(_ point: CGPoint) -> Bool {
        return outlinePath.contains(point)
    }
                
}

extension TurnoutShape: RotableShape {
    var rotationAngle: CGFloat {
        get {
            return turnout.rotationAngle
        }
        set {
            turnout.rotationAngle = newValue
        }
    }
        
    var rotationCenter: CGPoint {
        return center
    }
    
    var rotationPoint: CGPoint {
        let anchor = CGPoint(x: center.x, y: center.y - 1.5 * radius)
        let r = anchor.rotate(by: rotationAngle, around: center)
        return r
    }

    var rotationHandle: CGPath {
        let r = rotationPoint
        let size = 10.0
        return CGPath(ellipseIn: CGRect(x: r.x-size/2, y: r.y-size/2, width: size, height: size), transform: nil)
    }

}

extension TurnoutShape: ActionableShape {
    
    func performAction(at location: CGPoint) -> Bool {
        if inside(location) {
            layout.toggleTurnoutToNextState(turnout: turnout)
            return true
        } else {
            return false
        }
    }
        
}
