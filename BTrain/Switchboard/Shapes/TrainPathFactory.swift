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

struct TrainPathFactory {
    
    let shapeContext: ShapeContext

    var center: CGPoint = .zero
    var rotationAngle: CGFloat = 0

    var size: CGSize {
        CGSize(width: 16, height: shapeContext.trackWidth * 4)
    }

    func path(for part: TrainInstance.TrainPart, center: CGPoint, rotationCenter: CGPoint, rotationAngle: Double) -> CGPath {
        switch part {
        case .locomotive:
            return locomotive(center: center, rotationCenter: rotationCenter, rotationAngle: rotationAngle)
        case .wagon:
            return wagon(center: center, rotationCenter: rotationCenter, rotationAngle: rotationAngle)
        }
    }
    
    func locomotive(center: CGPoint, rotationCenter: CGPoint, rotationAngle: Double) -> CGPath {
        let rect = CGRect(origin: CGPoint(x: center.x-size.width/2, y: center.y-size.height/2), size: size)
        let path = CGMutablePath()
        let t = CGAffineTransform(translationX: rotationCenter.x, y: rotationCenter.y).rotated(by: rotationAngle).translatedBy(x: -rotationCenter.x, y: -rotationCenter.y)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY), transform: t)
        path.addLine(to: CGPoint(x: rect.minX+size.width/2, y: rect.minY), transform: t)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - shapeContext.trackWidth/2), transform: t)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY + shapeContext.trackWidth/2), transform: t)
        path.addLine(to: CGPoint(x: rect.minX+size.width/2, y: rect.maxY), transform: t)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY), transform: t)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY), transform: t)
        return path
    }

    func wagon(center: CGPoint, rotationCenter: CGPoint, rotationAngle: Double) -> CGPath {
        let rect = CGRect(origin: CGPoint(x: center.x-size.width/2, y: center.y-size.height/2), size: size)
        let t = CGAffineTransform(translationX: rotationCenter.x, y: rotationCenter.y).rotated(by: rotationAngle).translatedBy(x: -rotationCenter.x, y: -rotationCenter.y)
        let path = CGMutablePath()
        path.addRect(rect, transform: t)
        return path
    }

}
