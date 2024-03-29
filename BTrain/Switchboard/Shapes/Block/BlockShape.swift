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

import CoreGraphics
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
            block.center
        }
        set {
            block.center = newValue
        }
    }

    var bounds: CGRect {
        path.boundingBox
    }

    var boundsIncludingLabels: CGRect {
        var r = bounds
        for path in labelPaths {
            r = r.union(path.path.boundingBox)
        }
        return r
    }

    weak var layout: Layout?
    let block: Block

    var visible = true

    var selected = false

    var identifier: String {
        "block-\(block.id)"
    }

    var sockets: [ConnectorSocket] {
        switch block.category {
        case .station, .free:
            return [nextSocket, previousSocket]
        case .sidingPrevious:
            return [nextSocket]
        case .sidingNext:
            return [previousSocket]
        }
    }

    var freeSockets: [ConnectorSocket] {
        // Returns all the sockets that don't have any transitions coming out of them
        sockets.filter { connectorSocket in
            let s = Socket.block(block.id, socketId: connectorSocket.id)
            return (try? layout?.transition(from: s)) == nil
        }
    }

    var reserved: Reservation? {
        block.reservation
    }

    var train: Train? {
        layout?.trains[block.trainInstance?.trainId]
    }

    var path: CGPath {
        let rect = CGRect(origin: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2), size: size)
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
        path.move(to: CGPoint(x: center.x - size.width / 2, y: center.y), transform: t)
        path.addLine(to: CGPoint(x: center.x + size.width / 2, y: center.y), transform: t)

        if block.category == .sidingNext {
            path.move(to: CGPoint(x: center.x + size.width / 2, y: center.y - size.height / 2), transform: t)
            path.addLine(to: CGPoint(x: center.x + size.width / 2, y: center.y + size.height / 2), transform: t)
        }
        if block.category == .sidingPrevious {
            path.move(to: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2), transform: t)
            path.addLine(to: CGPoint(x: center.x - size.width / 2, y: center.y + size.height / 2), transform: t)
        }
        return path
    }

    /// The length of the line point which is used to determine when two lines representing
    /// each element are joining, in order to determine the control point of the bezier curve.
    let linePointLength = 160.0

    var nextSocket: ConnectorSocket {
        let socketCenter = CGPoint(x: center.x + size.width / 2, y: center.y)
            .rotate(by: rotationAngle, around: center)
        let ctrlPoint = CGPoint(x: center.x + size.width, y: center.y)
            .rotate(by: rotationAngle, around: center)
        let linePoint = CGPoint(x: center.x + size.width * linePointLength, y: center.y)
            .rotate(by: rotationAngle, around: center)
        return ConnectorSocket.create(id: Block.nextSocket, center: socketCenter, controlPoint: ctrlPoint, linePoint: linePoint)
    }

    var previousSocket: ConnectorSocket {
        let socketCenter = CGPoint(x: center.x - size.width / 2, y: center.y)
            .rotate(by: rotationAngle, around: center)
        let ctrlPoint = CGPoint(x: center.x - size.width, y: center.y)
            .rotate(by: rotationAngle, around: center)
        let linePoint = CGPoint(x: center.x - size.width * linePointLength, y: center.y)
            .rotate(by: rotationAngle, around: center)
        return ConnectorSocket.create(id: Block.previousSocket, center: socketCenter, controlPoint: ctrlPoint, linePoint: linePoint)
    }

    var nextSocketInstance: ConnectorSocketInstance {
        ConnectorSocketInstance(shape: self, socketId: nextSocket.id)
    }

    var previousSocketInstance: ConnectorSocketInstance {
        ConnectorSocketInstance(shape: self, socketId: previousSocket.id)
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
        ctx.setStrokeColor(shapeContext.pathColor(reserved != nil, train: block.trainInstance != nil))
        ctx.setLineWidth(shapeContext.trackWidth)
        if !block.enabled {
            ctx.setLineDash(phase: 0, lengths: [6, 6])
        }
        ctx.strokePath()
    }

    private func drawFeedbacks(ctx: CGContext) {
        for (index, feedback) in block.feedbacks.enumerated() {
            if let f = layout?.feedbacks[feedback.feedbackId], f.detected {
                ctx.setFillColor(shapeContext.activeFeedbackColor)
            } else {
                ctx.setFillColor(shapeContext.inactiveFeedbackColor)
            }

            let path = feedbackPath(at: index)
            ctx.addPath(path)
            ctx.fillPath()

            ctx.addPath(path)
            ctx.setStrokeColor(shapeContext.pathColor(reserved != nil, train: block.trainInstance != nil))
            ctx.strokePath()

            if let feedbackIds = shapeContext.expectedFeedbackIds, feedbackIds.contains(feedback.feedbackId) {
                let path = expectedFeedbackPath(at: index)
                ctx.addPath(path)
                ctx.strokePath()
            }

            if let feedbackIds = shapeContext.unexpectedFeedbackIds, feedbackIds.contains(feedback.feedbackId) {
                let path = unexpectedFeedbackPath(at: index)
                ctx.addPath(path)
                ctx.setFillColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.5)
                ctx.fillPath()
            }
        }
    }

    /// An array of label paths that will be used to determine if the user taps on any labels
    /// when dragging the train from this block
    internal var labelPaths = [BlockShapeLabelPath]()

    func drawLabels(ctx: CGContext, forceHideBlockName: Bool = false) {
        let showBlockName = (shapeContext.showBlockName || block.category == .station && shapeContext.showStationName)
        let showIcon = shapeContext.showTrainIcon && block.blockContainsLocomotive

        var labels = [BlockShapeLabel]()

        if showBlockName {
            let blockNameLabel = BlockShape_TextLabel(ctx: ctx, text: block.name, borderColor: shapeContext.borderLabelColor, shapeContext: shapeContext, hidden: forceHideBlockName)
            labels.append(blockNameLabel)
        }

        if let train = train {
            if let icon = shapeContext.locomotiveIconManager?.icon(for: train.locomotive?.id), showIcon {
                let trainIconLabel = BlockShape_IconLabel(ctx: ctx, icon: icon, shapeContext: shapeContext)
                labels.append(trainIconLabel)
            } else {
                let trainNameLabel = BlockShape_TextLabel(ctx: ctx, text: train.name, borderColor: shapeContext.trainColor(train), shapeContext: shapeContext)
                labels.append(trainNameLabel)
            }

            if train.timeUntilAutomaticRestart > 0 {
                let timeRemainingLabel = BlockShape_TextLabel(ctx: ctx, text: "􀐫 \(Int(train.timeUntilAutomaticRestart)) s.", borderColor: shapeContext.borderLabelColor, shapeContext: shapeContext)
                labels.append(timeRemainingLabel)
            }
        }

        drawLabels(labels: labels)
    }

    private func drawLabels(labels: [BlockShapeLabel]) {
        let space = CGFloat(12.0)
        let totalWidth = labels.reduce(0) { partialResult, label in partialResult + label.size.width } + space * CGFloat(labels.count - 1)

        labelPaths.removeAll()

        var cursor = center.translatedBy(x: -totalWidth / 2, y: -size.height / 1.5)
        for label in labels {
            let anchor = cursor.rotate(by: labelRotationAngle, around: rotationCenter)
            if let drawable = label.draw(at: anchor, rotation: labelRotationAngle, rotationCenter: rotationCenter) {
                labelPaths.append(drawable)
            }
            cursor = cursor.translatedBy(x: label.size.width + space, y: 0)
        }
    }

    func drawTrainParts(ctx: CGContext, lineBetweenParts: Bool = false) {
        guard let parts = block.trainInstance?.parts, let train = train else {
            return
        }

        let factory = TrainPathFactory(shapeContext: shapeContext)
        ctx.setFillColor(shapeContext.trainColor(train))

        var partsCenter = [CGPoint]()
        for index in 0 ... trainCellCount {
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

        if !partsCenter.isEmpty, lineBetweenParts {
            ctx.addLines(between: partsCenter)
            ctx.setStrokeColor(shapeContext.pathColor(reserved != nil, train: block.trainInstance != nil))
            ctx.setLineWidth(shapeContext.trackWidth)
            ctx.strokePath()
        }
    }

    func inside(_ point: CGPoint) -> Bool {
        path.contains(point)
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
        path.move(to: CGPoint(x: arrowCenterX - arrowLength / 2, y: arrowCenterY - arrowHeight / 2), transform: t)
        path.addLine(to: CGPoint(x: arrowCenterX + arrowLength / 2, y: arrowCenterY), transform: t)
        path.addLine(to: CGPoint(x: arrowCenterX - arrowLength / 2, y: arrowCenterY + arrowHeight / 2), transform: t)
        return path
    }

    func directionOfTravel() -> Direction {
        if let train = block.trainInstance {
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
            ctx.setStrokeColor(shapeContext.pathColor(reserved != nil, train: block.trainInstance != nil))
            ctx.setLineWidth(shapeContext.trackWidth)
            ctx.strokePath()
        } else {
            ctx.addPath(previousArrowPath(side: .previous, direction: .next))
            ctx.setStrokeColor(regularColor)
            ctx.setLineWidth(shapeContext.trackWidth)
            ctx.strokePath()

            ctx.addPath(previousArrowPath(side: .next, direction: .previous))
            ctx.setStrokeColor(shapeContext.pathColor(reserved != nil, train: block.trainInstance != nil))
            ctx.setLineWidth(shapeContext.trackWidth)
            ctx.strokePath()
        }
    }
}

// MARK: Train and Feedback

extension BlockShape {
    var edge: CGFloat {
        5
    }

    var arrowHeight: CGFloat {
        size.height / 2
    }

    var arrowLength: CGFloat {
        edge * 2
    }

    var feedbackCellCount: Int {
        block.feedbacks.count
    }

    var trainCellCount: Int {
        feedbackCellCount + 1
    }

    var size: CGSize {
        let width = CGFloat(feedbackCellCount) * feedbackWidth + CGFloat(trainCellCount) * trainSpaceWidth + 2 * edge + 2 * arrowLength
        return CGSize(width: max(width, 100), height: 30)
    }

    var leftSide: CGPoint {
        CGPoint(x: center.x - size.width / 2, y: center.y)
    }

    var rightSide: CGPoint {
        CGPoint(x: center.x + size.width / 2, y: center.y)
    }

    var feedbackWidth: CGFloat {
        10.0
    }

    var trainSpaceWidth: CGFloat {
        20.0
    }

    func trainCellFrame(at index: Int) -> CGRect {
        let x = leftSide.x + edge + arrowLength + CGFloat(index) * trainSpaceWidth + CGFloat(index) * feedbackWidth
        let y = center.y - size.height / 2
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
        let y = center.y - size.height / 2
        let rect = CGRect(origin: CGPoint(x: x, y: y), size: CGSize(width: feedbackWidth, height: size.height))
        return rect
    }

    func feedbackPath(at index: Int) -> CGPath {
        let rect = feedbackCellFrame(at: index)
        let size = min(rect.width, rect.height)
        let feedbackRect = CGRect(x: rect.origin.x + (rect.width - size) / 2, y: rect.origin.y + (rect.height - size) / 2, width: size, height: size)
        var t = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: rotationAngle).translatedBy(x: -center.x, y: -center.y)
        let path = CGPath(roundedRect: feedbackRect, cornerWidth: 2, cornerHeight: 2, transform: &t)
        return path
    }

    func expectedFeedbackPath(at index: Int) -> CGPath {
        let rect = feedbackCellFrame(at: index)
        var t = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: rotationAngle).translatedBy(x: -center.x, y: -center.y)
        let path = CGMutablePath()
        path.addPath(CGPath(rect: CGRect(x: rect.origin.x, y: rect.origin.y + rect.height * 3 / 4, width: rect.width, height: 1), transform: &t))
        path.addPath(CGPath(rect: CGRect(x: rect.origin.x, y: rect.origin.y + rect.height * 1 / 4, width: rect.width, height: -1), transform: &t))
        return path
    }

    func unexpectedFeedbackPath(at index: Int) -> CGPath {
        let rect = feedbackCellFrame(at: index)
        let t = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: rotationAngle).translatedBy(x: -center.x, y: -center.y)
        let path = CGMutablePath()
        let size = 40.0
        path.addEllipse(in: .init(origin: rect.center.translatedBy(x: -size / 2, y: -size / 2), size: .init(width: size, height: size)), transform: t)
        return path
    }
}

extension BlockShape: ActionableShape {
    func performAction(at location: CGPoint) -> Bool {
        for (index, blockFeedback) in block.feedbacks.enumerated() {
            let path = feedbackPath(at: index)
            if path.contains(location), let feedback = layout?.feedbacks[blockFeedback.feedbackId] {
                shapeContext.simulator?.setFeedback(feedback: feedback, value: feedback.detected ? 0 : 1)
                return true
            }
        }
        return false
    }
}

extension BlockShape: RotableShape {
    var rotationCenter: CGPoint {
        center
    }

    var rotationAngle: CGFloat {
        get {
            block.rotationAngle
        }
        set {
            block.rotationAngle = newValue
        }
    }

    // The rotation angle adjust in order to always see the labels at the top
    // of the block regardless of the rotationAngle
    var labelRotationAngle: CGFloat {
        let angle = rotationAngle.truncatingRemainder(dividingBy: 2 * .pi)
        if abs(angle) <= .pi / 2 || abs(angle) >= 2 * .pi * 3 / 4 {
            return angle
        } else {
            return angle + .pi
        }
    }

    var rotationHandle: CGPath {
        let r = rotationPoint
        let size = 10.0
        return CGPath(ellipseIn: CGRect(x: r.x - size / 2, y: r.y - size / 2, width: size, height: size), transform: nil)
    }

    var rotationPoint: CGPoint {
        let anchor = CGPoint(x: center.x, y: center.y - size.height)
        let r = anchor.rotate(by: rotationAngle, around: center)
        return r
    }
}
