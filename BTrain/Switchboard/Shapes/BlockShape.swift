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

    weak var layout: Layout?
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
            return (try? layout?.transition(from: s)) == nil
        }
    }
    
    var reserved: Reservation? {
        return block.reserved
    }
    
    var train: Train? {
        return layout?.train(for: block.train?.trainId)
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
        let linePoint = CGPoint(x: center.x + size.width * 4 * 4, y: center.y)
            .rotate(by: rotationAngle, around: center)
        return ConnectorSocket.create(id: Block.nextSocket, center: socketCenter, controlPoint: ctrlPoint, linePoint: linePoint)
    }

    var previousSocket: ConnectorSocket {
        let socketCenter = CGPoint(x: center.x - size.width/2, y: center.y)
            .rotate(by: rotationAngle, around: center)
        let ctrlPoint = CGPoint(x: center.x - size.width, y: center.y)
            .rotate(by: rotationAngle, around: center)
        let linePoint = CGPoint(x: center.x - size.width * 4, y: center.y)
            .rotate(by: rotationAngle, around: center)
        return ConnectorSocket.create(id: Block.previousSocket, center: socketCenter, controlPoint: ctrlPoint, linePoint: linePoint)
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
        ctx.with {
            drawBackground(ctx: ctx)
        }

        ctx.with {
            drawArrows(ctx: ctx)
        }

        ctx.with {
            drawTracks(ctx: ctx)
        }
        
        ctx.with {
            drawFeedbacks(ctx: ctx)
        }
        
        ctx.with {
            drawTrainParts(ctx: ctx)
        }

        ctx.with {
            drawTimeRemaining(ctx: ctx)
        }
        
        ctx.with {
            drawLabels(ctx: ctx)
        }
    }

    private func drawBackground(ctx: CGContext) {
        if block.category == .station {
            ctx.addPath(path)
            ctx.setFillColor(shapeContext.backgroundStationBlockColor)
            ctx.fillPath()
        }
    }
    
    private func drawTracks(ctx: CGContext) {
        ctx.addPath(trackPath)
        ctx.setStrokeColor(shapeContext.pathColor(reserved != nil, train: block.train != nil))
        ctx.setLineWidth(shapeContext.trackWidth)
        if !block.enabled {
            ctx.setLineDash(phase: 0, lengths: [6, 6])
        }
        ctx.strokePath()
    }
    
    private func drawFeedbacks(ctx: CGContext) {
        for (index, feedback) in block.feedbacks.enumerated() {
            if let f = layout?.feedback(for: feedback.feedbackId), f.detected {
                ctx.setFillColor(shapeContext.activeFeedbackColor)
            } else {
                ctx.setFillColor(shapeContext.inactiveFeedbackColor)
            }
            
            let path = feedbackPath(at: index)
            ctx.addPath(path)
            ctx.fillPath()
            
            ctx.addPath(path)
            ctx.setStrokeColor(shapeContext.pathColor(reserved != nil, train: block.train != nil))
            ctx.strokePath()
            
            if let feedbackIds = shapeContext.expectedFeedbackIds, feedbackIds.contains(feedback.feedbackId) {
                let path = expectedFeedbackPath(at: index)
                ctx.addPath(path)
                ctx.strokePath()
            }
        }
    }
    
    private func drawTimeRemaining(ctx: CGContext) {
        // Display the time remaining until the train starts again
        if let train = train, train.timeUntilAutomaticRestart > 0 {
            drawLabel(ctx: ctx, label: "\(Int(train.timeUntilAutomaticRestart)) s.", at: center, verticalOffset: size.height/2, hAlignment: .center, vAlignment: .top,
                      color: shapeContext.color, fontSize: shapeContext.fontSize, borderColor: shapeContext.borderLabelColor, backgroundColor: shapeContext.backgroundLabelColor)
        }
    }
    
    func drawLabels(ctx: CGContext, forceHideBlockName: Bool = false) {
        let showBlockName = (shapeContext.showBlockName || block.category == .station && shapeContext.showStationName) && !forceHideBlockName
        let showIcon = shapeContext.showTrainIcon && prepareIcon() != nil && block.blockContainsLocomotive

        if let train = train {
            if showBlockName {
                let (_, blockNameRect) = ctx.prepareText(text: block.name, color: shapeContext.color, fontSize: shapeContext.fontSize)
                let (_, trainNameRect) = ctx.prepareText(text: train.name, color: shapeContext.color, fontSize: shapeContext.fontSize)

                let blockNameSize: CGSize = blockNameRect.size
                let trainNameSize: CGSize
                
                if showIcon {
                    trainNameSize = prepareIcon() ?? .zero
                } else {
                    trainNameSize = trainNameRect.size
                }

                let maxHeight = max(blockNameSize.height, trainNameSize.height)
                
                let space = 12.0
                
                let totalWidth = trainNameSize.width + space + blockNameSize.width
                                
                ctx.with {
                    let adjustHeight = maxHeight - blockNameSize.height
                    drawLabel(ctx: ctx, label: block.name, at: center.translatedBy(x: -totalWidth/2, y: 0), verticalOffset: -size.height/2 - adjustHeight/2,
                                  color: shapeContext.color, fontSize: shapeContext.fontSize, borderColor: shapeContext.borderLabelColor, backgroundColor: shapeContext.backgroundLabelColor)
                }
                
                let adjustHeight = maxHeight - trainNameSize.height
                if showIcon {
                    drawIcon(ctx: ctx, at: center,
                             verticalOffset: size.height/2 + adjustHeight/2,
                             horizontalOffset: totalWidth/2 - trainNameSize.width)
                } else {
                    drawLabel(ctx: ctx, label: train.name, at: center.translatedBy(x: blockNameSize.width + space - totalWidth/2, y: 0), verticalOffset: -size.height/2 - adjustHeight/2,
                              color: shapeContext.color, fontSize: shapeContext.fontSize, borderColor: shapeContext.trainColor(train), backgroundColor: shapeContext.backgroundLabelColor)
                }
            } else {
                if showIcon {
                    drawIcon(ctx: ctx, at: center, verticalOffset: size.height/2, hAlignment: .center)
                } else {
                    drawLabel(ctx: ctx, label: train.name, at: center, verticalOffset: -size.height/2, hAlignment: .center, color: shapeContext.color, fontSize: shapeContext.fontSize,
                                          borderColor: shapeContext.trainColor(train), backgroundColor: shapeContext.backgroundLabelColor)
                }
            }
        } else {
            if showBlockName {
                drawLabel(ctx: ctx, label: block.name, at: center, verticalOffset: -size.height/2, hAlignment: .center,
                          color: shapeContext.color, fontSize: shapeContext.fontSize, borderColor: shapeContext.borderLabelColor, backgroundColor: shapeContext.backgroundLabelColor)
            }
        }
    }

    @discardableResult
    func drawLabel(ctx: CGContext, label: String, at location: CGPoint, verticalOffset: CGFloat, hAlignment: HTextAlignment = .left, vAlignment: VTextAlignment = .bottom, color: CGColor, fontSize: CGFloat, borderColor: CGColor? = nil, backgroundColor: CGColor? = nil) -> CGSize {

        // Always displays the text facing downwards so it is easer to read
        let textCenter = location.translatedBy(x: 0, y: verticalOffset).rotate(by: labelRotationAngle, around: rotationCenter)
        return ctx.drawText(at: textCenter, vAlignment: vAlignment, hAlignment: hAlignment, rotation: labelRotationAngle,
                            text: label, color: color, fontSize: fontSize, borderColor: borderColor, backgroundColor: backgroundColor)
    }

    func drawTrainParts(ctx: CGContext, lineBetweenParts: Bool = false) {
        guard let parts = block.train?.parts, let train = train else {
            return
        }
        
        let factory = TrainPathFactory(shapeContext: shapeContext)
        ctx.setFillColor(shapeContext.trainColor(train))
        
        var partsCenter = [CGPoint]()
        for index in 0...trainCellCount {
            if let part = parts[index] {
                let rect = trainCellPath(at: index)
                let center = rect.boundingBox.center
                let rotationAngle = directionOfTravel() == .next ? rotationAngle : rotationAngle + .pi // take into account the direction of travel of the train
                let path = factory.path(for: part, center: center, rotationCenter: center, rotationAngle: rotationAngle)
                ctx.addPath(path)
                ctx.fillPath()
                
                partsCenter.append(path.boundingBox.center)
            }
        }
        
        if !partsCenter.isEmpty && lineBetweenParts {
            ctx.addLines(between: partsCenter)
            ctx.setStrokeColor(shapeContext.pathColor(reserved != nil, train: block.train != nil))
            ctx.setLineWidth(shapeContext.trackWidth)
            ctx.strokePath()
        }
    }
    
    func inside(_ point: CGPoint) -> Bool {
        return path.contains(point)
    }

}

extension BlockShape {
    
    func prepareIcon() -> CGSize? {
        guard let train = train else {
            return nil
        }
        
        guard let image = shapeContext.trainIconManager?.icon(for: train.id) else {
            return nil
        }
                
        let ratio = image.size.width / image.size.height
        let height = shapeContext.fontSize * 2
        let width = height * ratio

        return CGSize(width: width, height: height)
    }
    
    func drawIcon(ctx: CGContext, at center: CGPoint, verticalOffset: CGFloat = 0, horizontalOffset: CGFloat = 0, hAlignment: HTextAlignment = .left) {
        guard let train = train else {
            return
        }
        
        guard let image = shapeContext.trainIconManager?.icon(for: train.id) else {
            return
        }
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }
        
        let ratio = image.size.width / image.size.height
        let height = shapeContext.fontSize * 2
        let width = height * ratio

        ctx.with {
            // Maintain rotation such that the icon is always on top or to the left
            var transform = CGAffineTransform.identity
                .rotation(by: labelRotationAngle, around: center)

            // Flip the icon vertically
            transform = transform
                .translatedBy(x: center.x, y: center.y)
                .scaledBy(x: 1.0, y: -1.0)
                .translatedBy(x: -center.x, y: -center.y)
            
            // Apply translation
            switch hAlignment {
            case .center:
                transform = transform.translatedBy(x: -width/2, y: 0)
            case .left:
                break
            case .right:
                transform = transform.translatedBy(x: width/2, y: 0)
            }

            transform = transform.translatedBy(x: horizontalOffset, y: verticalOffset)
            ctx.concatenate(transform)

            ctx.draw(cgImage, in: CGRect(x: center.x, y: center.y, width: width, height: height))
        }
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
            ctx.addPath(previousArrowPath(side: .previous, direction: .next))
            ctx.setStrokeColor(shapeContext.pathColor(reserved != nil, train: block.train != nil))
            ctx.setLineWidth(shapeContext.trackWidth)
            ctx.strokePath()
        } else {
            ctx.addPath(previousArrowPath(side: .previous, direction: .next))
            ctx.setStrokeColor(regularColor)
            ctx.setLineWidth(shapeContext.trackWidth)
            ctx.strokePath()
            
            ctx.addPath(previousArrowPath(side: .next, direction: .previous))
            ctx.setStrokeColor(shapeContext.pathColor(reserved != nil, train: block.train != nil))
            ctx.setLineWidth(shapeContext.trackWidth)
            ctx.strokePath()
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

    func trainCellPath(at index: Int) -> CGPath {
        let rect = trainCellFrame(at: index)
        var t = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: rotationAngle).translatedBy(x: -center.x, y: -center.y)
        return CGPath(rect: rect, transform: &t)
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

    func expectedFeedbackPath(at index: Int) -> CGPath {
        let rect = feedbackCellFrame(at: index)
        var t = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: rotationAngle).translatedBy(x: -center.x, y: -center.y)
        let path = CGMutablePath()
        path.addPath(CGPath(rect: CGRect(x: rect.origin.x, y: rect.origin.y + rect.height * 3/4, width: rect.width, height: 1), transform: &t))
        path.addPath(CGPath(rect: CGRect(x: rect.origin.x, y: rect.origin.y + rect.height * 1/4, width: rect.width, height: -1), transform: &t))
        return path
    }

}

extension BlockShape: ActionableShape {
    
    func performAction(at location: CGPoint) -> Bool {
        for (index, blockFeedback) in block.feedbacks.enumerated() {
            let path = feedbackPath(at: index)
            if path.contains(location), let feedback = layout?.feedback(for: blockFeedback.feedbackId) {
                shapeContext.simulator?.setFeedback(feedback: feedback, value: feedback.detected ? 0 : 1)
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
    
    // The rotation angle adjust in order to always see the labels at the top
    // of the block regardless of the rotationAngle
    var labelRotationAngle: CGFloat {
        let angle = rotationAngle.truncatingRemainder(dividingBy: 2 * .pi)
        if abs(angle) <= .pi/2 || abs(angle) >= 2 * .pi*3/4 {
            return angle
        } else {
            return angle + .pi
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
