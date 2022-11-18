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

extension ShapeProvider {
    func updateControlPointShapes(visible: Bool) {
        assignControlPoints()
        createControlPointShapes(visible: visible)
    }

    private func assignControlPoints() {
        for linkShape in linkShapes {
            // Note: link that are being created by the user can have no transition associated with it until the
            // user has finished connecting both ends of the link shape.
            guard let transition = linkShape.transition else {
                continue
            }
            let controlPoints = layout.controlPoints.filter { $0.transitionId == transition.id }
            if controlPoints.count == 2 {
                linkShape.controlPoint1 = controlPoints[0]
                linkShape.controlPoint2 = controlPoints[1]
            }
        }
    }

    func toggleControlPoints(_ shape: LinkShape) {
        guard let transition = shape.transition else {
            return
        }

        removeControlPointShapes()

        let existingControlPoints = layout.controlPoints.filter { $0.transitionId == transition.id }
        if existingControlPoints.isEmpty {
            addControlPoint(transition: transition, shape: shape, position: shape.ctrlPoint1)
            addControlPoint(transition: transition, shape: shape, position: shape.ctrlPoint2)
        } else {
            layout.controlPoints.removeAll { $0.transitionId == transition.id }
            for linkShape in linkShapes.filter({ $0.transition?.id == transition.id }) {
                linkShape.controlPoint1 = nil
                linkShape.controlPoint2 = nil
            }
        }

        // Note: make sure the control points are visible because we are editing the switchboard
        updateControlPointShapes(visible: true)
    }

    private func addControlPoint(transition: Transition, shape _: LinkShape, position: CGPoint) {
        let id = LayoutIdentity.newIdentity(layout.controlPoints, prefix: .controlPoint)
        let controlPoint = ControlPoint(id: id, transitionId: transition.id, position: position)
        layout.controlPoints.append(controlPoint)
    }

    private func createControlPointShapes(visible: Bool) {
        for linkShape in linkShapes {
            if let cp1 = linkShape.controlPoint1 {
                createControlPointShape(controlPoint: cp1, visible: visible)
            }
            if let cp2 = linkShape.controlPoint2 {
                createControlPointShape(controlPoint: cp2, visible: visible)
            }
        }
    }

    private func createControlPointShape(controlPoint: ControlPoint, visible: Bool) {
        let controlPointShape = ControlPointShape(controlPoint: controlPoint, shapeContext: context)
        controlPointShape.controlPoint.position = controlPoint.position
        controlPointShape.visible = visible
        append(controlPointShape)
    }

    private var controlPointShapes: [ControlPointShape] {
        shapes.compactMap { $0 as? ControlPointShape }
    }

    func showControlPointShapes() {
        for shape in controlPointShapes {
            shape.visible = true
        }
    }

    func hideControlPointShapes() {
        for shape in controlPointShapes {
            shape.visible = false
        }
    }
}
