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

// A block is represented by the following components:
//
//                                     feedback index 1 ──┐
//                                                        │
//                feedback index 0 ────┐                  │
//                                     │                  │
//                                     ▼                  ▼
//      ┌────┐┌─────────┐┌───────┐┌────────┐┌───────┐┌────────┐┌─────────┐┌────┐
//  p   │    ││         ││       ││        ││       ││        ││         ││    │  n
//  r   │    ││  block  ││       ││        ││       ││        ││  train  ││    │  e
//  e   │edge││  arrow  ││ train ││feedback││ train ││feedback││  arrow  ││edge│  x
//  v   │    ││direction││ space ││ space  ││ space ││ space  ││direction││    │  t
//  i   │    ││         ││       ││        ││       ││        ││         ││    │
//  o   │    ││         ││       ││        ││       ││        ││         ││    │  s
//  u   └────┘└─────────┘└───────┘└────────┘└───────┘└────────┘└─────────┘└────┘  i
//  s                        ▲                  ▲                                 d
//                           │                  │                                 e
//          train index 0  ──┘                  │
//                                              │
//                              train index 1  ─┘
//
//       ─────────────────────────────────────────────────────────────────────▶
//                              block natural direction
final class BlockShape: Shape, DraggableShape, ConnectableShape {
    
    let shapeContext: ShapeContext
    
    var center: CGPoint {
        get {
            return block.center
        }
        set {
            block.center = newValue
        }
    }
        
    var bounds: CGRect {
        return path.boundingBox
    }

    let layout: Layout
    let block: Block

    var visible = true

    var selected = false

    var identifier: String {
        return "block-\(block.id)"
    }

    var sockets: [ConnectorSocket] {
        switch(block.category) {
        case .station, .free:
            return [ nextSocket, previousSocket ]
        case .sidingPrevious:
            return [ nextSocket ]
        case .sidingNext:
            return [ previousSocket ]
        }
    }
    
    var freeSockets: [ConnectorSocket] {
        // Returns all the sockets that don't have any transitions coming out of them
        return sockets.filter { connectorSocket in
            let s = Socket.block(block.id, socketId: connectorSocket.id)
            if let transitions = try? layout.transitions(from: s) {
                return transitions.isEmpty
            } else {
                return false
            }            
        }
    }
    
    var reserved: Reservation? {
        return block.reserved
    }
    
    var train: Train? {
        return layout.train(for: block.train?.trainId)
    }
        
    var path: CGPath {
        let rect = CGRect(origin: CGPoint(x: center.x-size.width/2, y: center.y-size.height/2), size: size)
        var t = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: rotationAngle).translatedBy(x: -center.x, y: -center.y)
        if block.category == .station {
            let path = CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: &t)
            return path
        } else {
            let path = CGPath(rect: rect, transform: &t)
            return path
        }
    }
    
    var trackPath: CGPath {
        let path = CGMutablePath()
        let t = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: rotationAngle).translatedBy(x: -center.x, y: -center.y)
        path.move(to: CGPoint(x: center.x-size.width/2, y: center.y), transform: t)
        path.addLine(to: CGPoint(x: center.x+size.width/2, y: center.y), transform: t)
        
        if block.category == .sidingNext {
            path.move(to: CGPoint(x: center.x+size.width/2, y: center.y-size.height/2), transform: t)
            path.addLine(to: CGPoint(x: center.x+size.width/2, y: center.y+size.height/2), transform: t)
        }
        if block.category == .sidingPrevious {
            path.move(to: CGPoint(x: center.x-size.width/2, y: center.y-size.height/2), transform: t)
            path.addLine(to: CGPoint(x: center.x-size.width/2, y: center.y+size.height/2), transform: t)
        }
        return path
    }
    
    var nextSocket: ConnectorSocket {
        let socketCenter = CGPoint(x: center.x + size.width/2, y: center.y)
            .rotate(by: rotationAngle, around: center)
        let ctrlPoint = CGPoint(x: center.x + size.width, y: center.y)
            .rotate(by: rotationAngle, around: center)
        return ConnectorSocket.create(id: Block.nextSocket, center: socketCenter, controlPoint: ctrlPoint)
    }

    var previousSocket: ConnectorSocket {
        let socketCenter = CGPoint(x: center.x - size.width/2, y: center.y)
            .rotate(by: rotationAngle, around: center)
        let ctrlPoint = CGPoint(x: center.x - size.width, y: center.y)
            .rotate(by: rotationAngle, around: center)
        return ConnectorSocket.create(id: Block.previousSocket, center: socketCenter, controlPoint: ctrlPoint)
    }
        
    var nextSocketInstance: ConnectorSocketInstance {
        return ConnectorSocketInstance(shape: self, socketId: nextSocket.id)
    }

    var previousSocketInstance: ConnectorSocketInstance {
        return ConnectorSocketInstance(shape: self, socketId: previousSocket.id)
    }
    
    init(layout: Layout, block: Block, shapeContext: ShapeContext) {
        self.layout = layout
        self.block = block
        self.shapeContext = shapeContext
    }
        
    func draw(ctx: CGContext) {
        if block.category == .station {
            ctx.with {
                ctx.addPath(path)
                ctx.setFillColor(shapeContext.backgroundStationBlockColor)
                ctx.fillPath()
            }
        }
        
        drawArrows(ctx: ctx)

        ctx.with {
            ctx.addPath(trackPath)
            ctx.setStrokeColor(reserved != nil ? shapeContext.reservedColor : shapeContext.color)
            ctx.setLineWidth(shapeContext.trackWidth)
            if !block.enabled {
                ctx.setLineDash(phase: 0, lengths: [6, 6])
            }
            ctx.strokePath()
        }
        
        ctx.with {
            drawContent(ctx: ctx, shapeContext: shapeContext)
        }                
    }
        
    func drawContent(ctx: CGContext, shapeContext: ShapeContext) {
        let showBlockName = shapeContext.showBlockName || block.category == .station && shapeContext.showStationName
        if let train = train {
            if showBlockName {
                let (_, blockLabelRect) = prepareText(ctx: ctx, text: block.name, color: shapeContext.color, fontSize: shapeContext.fontSize)
                let (_, trainLabelRect) = prepareText(ctx: ctx, text: train.name, color: shapeContext.color, fontSize: shapeContext.fontSize)

                let maxHeight = max(blockLabelRect.height, trainLabelRect.height)
                
                let space = 12.0
                
                let totalWidth = blockLabelRect.width + trainLabelRect.width + space
                
                ctx.with {
                    let adjustHeight = maxHeight - blockLabelRect.height
                    drawLabel(ctx: ctx, label: block.name, at: center.translatedBy(x: -totalWidth/2, y: -size.height/2 - adjustHeight/2),
                              color: shapeContext.color, fontSize: shapeContext.fontSize, borderColor: shapeContext.borderLabelColor, backgroundColor: shapeContext.backgroundLabelColor)
                }
                ctx.with {
                    let adjustHeight = maxHeight - trainLabelRect.height
                    drawLabel(ctx: ctx, label: train.name, at: center.translatedBy(x: blockLabelRect.width + space - totalWidth/2, y: -size.height/2 - adjustHeight/2),
                              color: shapeContext.color, fontSize: shapeContext.fontSize, borderColor: shapeContext.trainColor(train), backgroundColor: shapeContext.backgroundLabelColor)
                }
            } else {
                ctx.with {
                    drawLabel(ctx: ctx, label: train.name, at: center.translatedBy(x: 0, y: -size.height/2), centered: true, color: shapeContext.color, fontSize: shapeContext.fontSize,
                                          borderColor: shapeContext.trainColor(train), backgroundColor: shapeContext.backgroundLabelColor)
                }
            }
        } else {
            if showBlockName {
                ctx.with {
                    drawLabel(ctx: ctx, label: block.name, at: center.translatedBy(x: 0, y: -size.height/2), centered: true,
                              color: shapeContext.color, fontSize: shapeContext.fontSize, borderColor: shapeContext.borderLabelColor, backgroundColor: shapeContext.backgroundLabelColor)
                }
            }
        }
        
        for (index, feedback) in block.feedbacks.enumerated() {
            if let f = layout.feedback(for: feedback.feedbackId), f.detected {
                ctx.setFillColor(shapeContext.activeFeedbackColor)
            } else {
                ctx.setFillColor(shapeContext.inactiveFeedbackColor)
            }
            
            let path = feedbackPath(at: index)
            ctx.addPath(path)
            ctx.fillPath()
            
            ctx.addPath(path)
            ctx.setStrokeColor(reserved != nil ? shapeContext.reservedColor : shapeContext.color)
            ctx.strokePath()
        }
    }

    @discardableResult
    func drawLabel(ctx: CGContext, label: String, at location: CGPoint, centered: Bool = false, color: CGColor, fontSize: CGFloat, borderColor: CGColor? = nil, backgroundColor: CGColor? = nil) -> CGSize {
        let textCenter = location.rotate(by: rotationAngle, around: rotationCenter)

        // Always displays the text facing downwards so it is easer to read
        let angle = rotationAngle.truncatingRemainder(dividingBy: 2 * .pi)
        if abs(angle) <= .pi/2 || abs(angle) >= 2 * .pi*3/4 {
            return drawText(ctx: ctx, at: textCenter, vAlignment: .bottom, hAlignment: centered ? .center : .left, rotation: angle,
                            text: label, color: color, fontSize: fontSize, borderColor: borderColor, backgroundColor: backgroundColor)
        } else {
            return drawText(ctx: ctx, at: textCenter, vAlignment: .top, hAlignment: centered ? .center : .right, rotation: angle + .pi,
                            text: label, color: color, fontSize: fontSize, borderColor: borderColor, backgroundColor: backgroundColor)
        }
    }

    func inside(_ point: CGPoint) -> Bool {
        return path.contains(point)
    }

}

// MARK: Arrows

extension BlockShape {
    enum ArrowSide {
        case previous
        case next
    }
    
    func previousArrowPath(side: ArrowSide, direction: Direction) -> CGPath {
        let arrowCenterX: CGFloat
        if side == .previous {
            arrowCenterX = leftSide.x + edge + arrowLength / 2
        } else {
            arrowCenterX = rightSide.x - edge - arrowLength / 2
        }
        let arrowCenterY = center.y
        
        let arrowAngle = direction == .previous ? .pi : 0
                
        let t = CGAffineTransform.identity.rotation(by: arrowAngle, around: CGPoint(x: arrowCenterX, y: arrowCenterY)).rotation(by: rotationAngle, around: center)
        
        let path = CGMutablePath()
        path.move(to: CGPoint(x: arrowCenterX - arrowLength/2, y: arrowCenterY - arrowHeight/2), transform: t)
        path.addLine(to: CGPoint(x: arrowCenterX + arrowLength/2, y: arrowCenterY), transform: t)
        path.addLine(to: CGPoint(x: arrowCenterX - arrowLength/2, y: arrowCenterY + arrowHeight/2), transform: t)
        return path
    }

    func directionOfTravel() -> Direction {
        if let train = block.train {
            return train.direction
        } else if let reserved = reserved {
            return reserved.direction
        } else {
            return .next
        }
    }
    
    func drawArrows(ctx: CGContext) {
        let regularColor = shapeContext.color.copy(alpha: 0.5)!
        let direction = directionOfTravel()
        if direction == .next {
            ctx.with {
                ctx.addPath(previousArrowPath(side: .previous, direction: .next))
                ctx.setStrokeColor(reserved != nil ? shapeContext.reservedColor : regularColor)
                ctx.setLineWidth(shapeContext.trackWidth)
                ctx.strokePath()

                ctx.restoreGState()
            }
        } else {
            ctx.with {
                ctx.addPath(previousArrowPath(side: .previous, direction: .next))
                ctx.setStrokeColor(regularColor)
                ctx.setLineWidth(shapeContext.trackWidth)
                ctx.strokePath()
            }

            ctx.with {
                ctx.addPath(previousArrowPath(side: .next, direction: .previous))
                ctx.setStrokeColor(reserved != nil ? shapeContext.reservedColor : regularColor)
                ctx.setLineWidth(shapeContext.trackWidth)
                ctx.strokePath()
            }
        }
    }
    
}

// MARK: Train and Feedback

extension BlockShape {

    var edge: CGFloat {
        return 5
    }
    
    var arrowHeight: CGFloat {
        size.height/2
    }

    var arrowLength: CGFloat {
        edge * 2
    }
    
    var feedbackCellCount: Int {
        return block.feedbacks.count
    }
    
    var trainCellCount: Int {
        return feedbackCellCount + 1
    }
        
    var size: CGSize {
        let width = CGFloat(feedbackCellCount) * feedbackWidth + CGFloat(trainCellCount) * trainSpaceWidth + 2 * edge + 2 * arrowLength
        return CGSize(width: max(width, 100), height: 30)
    }
    
    var leftSide: CGPoint {
        return CGPoint(x: center.x-size.width/2, y: center.y)
    }
    
    var rightSide: CGPoint {
        return CGPoint(x: center.x+size.width/2, y: center.y)
    }

    var feedbackWidth: CGFloat {
        return 10.0
    }
    
    var trainSpaceWidth: CGFloat {
        return 20.0
    }
    
    func trainCellFrame(at index: Int) -> CGRect {
        let x = leftSide.x + edge + arrowLength + CGFloat(index) * trainSpaceWidth + CGFloat(index) * feedbackWidth
        let y = center.y - size.height/2
        let rect = CGRect(origin: CGPoint(x: x, y: y), size: CGSize(width: trainSpaceWidth, height: size.height))
        return rect
    }

    func feedbackCellFrame(at index: Int) -> CGRect {
        let x = leftSide.x + edge + arrowLength + CGFloat(index) * feedbackWidth + CGFloat(index + 1) * trainSpaceWidth
        let y = center.y-size.height/2
        let rect = CGRect(origin: CGPoint(x: x, y: y), size: CGSize(width: feedbackWidth, height: size.height))
        return rect
    }

    func feedbackPath(at index: Int) -> CGPath {
        let rect = feedbackCellFrame(at: index)
        let size = min(rect.width, rect.height)
        let feedbackRect = CGRect(x: rect.origin.x + (rect.width - size)/2, y: rect.origin.y + (rect.height - size)/2, width: size, height: size)
        var t = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: rotationAngle).translatedBy(x: -center.x, y: -center.y)
        let path = CGPath(roundedRect: feedbackRect, cornerWidth: 2, cornerHeight: 2, transform: &t)
        return path
    }

    func trainPath(at index: Int) -> CGPath {
        let rect = trainCellFrame(at: index)
        var t = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: rotationAngle).translatedBy(x: -center.x, y: -center.y)
        let path = CGPath(ellipseIn: rect, transform: &t)
        return path
    }
    
    func trainCellPath(at index: Int) -> CGPath {
        let rect = trainCellFrame(at: index)
        var t = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: rotationAngle).translatedBy(x: -center.x, y: -center.y)
        return CGPath(rect: rect, transform: &t)
    }

    func trainCellPath(at location: CGPoint) -> (Int, CGPath)? {
        for index in 0..<trainCellCount {
            let path = trainCellPath(at: index)
            if path.contains(location) {
                return (index, path)
            }
        }
        return nil
    }

}

extension BlockShape: ActionableShape {
    
    func performAction(at location: CGPoint) -> Bool {
        for (index, feedback) in block.feedbacks.enumerated() {
            let path = feedbackPath(at: index)
            if path.contains(location) {
                layout.feedback(for: feedback.feedbackId)?.detected.toggle()
                return true
            }
        }
        return false
    }
    
}

extension BlockShape: RotableShape {
    
    var rotationCenter: CGPoint {
        return center
    }
    
    var rotationAngle: CGFloat {
        get {
            return block.rotationAngle
        }
        set {
            block.rotationAngle = newValue
        }
    }
    
    var rotationHandle: CGPath {
        let r = rotationPoint
        let size = 10.0
        return CGPath(ellipseIn: CGRect(x: r.x-size/2, y: r.y-size/2, width: size, height: size), transform: nil)
    }
    
    var rotationPoint: CGPoint {
        let anchor = CGPoint(x: center.x, y: center.y - size.height)
        let r = anchor.rotate(by: rotationAngle, around: center)
        return r
    }
    
}
