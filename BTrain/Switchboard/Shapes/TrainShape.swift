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

final class TrainShape: Shape, DraggableShape {
    let layout: Layout
    let train: Train
    let shapeProvider: ShapeProviding
    let shapeContext: ShapeContext
    
    var center: CGPoint = .zero
    var rotationAngle: CGFloat = 0
    
    var identifier: String {
        return "\(train)-shape"
    }
    
    var selected = false
    
    var dragged = false
    
    var size: CGSize {
        return CGSize(width: 20, height: shapeContext.trackWidth*4)
    }
    
    var bounds: CGRect {
        return path.boundingBox
    }

    var path: CGPath {
        let rect = CGRect(origin: CGPoint(x: center.x-size.width/2, y: center.y-size.height/2), size: size)
        let path = CGMutablePath()
        let t = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: rotationAngle).translatedBy(x: -center.x, y: -center.y)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY), transform: t)
        path.addLine(to: CGPoint(x: rect.minX+size.width/2, y: rect.minY), transform: t)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - shapeContext.trackWidth/2), transform: t)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY + shapeContext.trackWidth/2), transform: t)
        path.addLine(to: CGPoint(x: rect.minX+size.width/2, y: rect.maxY), transform: t)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY), transform: t)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY), transform: t)
        return path
    }
    
    init(layout: Layout, train: Train, shapeProvider: ShapeProviding, shapeContext: ShapeContext) {
        self.layout = layout
        self.train = train
        self.shapeProvider = shapeProvider
        self.shapeContext = shapeContext
        updatePosition()
    }
    
    var visible: Bool {
        return train.blockId != nil
    }
    
    func updatePosition() {
        guard !dragged else {
            return
        }
        
        guard let blockId = train.blockId else {
            return
        }
        
        if let blockShape = shapeProvider.blockShape(for: blockId) {
            let locationShape = blockShape.trainPath(at: train.position)
            self.center = CGPoint(x: locationShape.boundingBox.midX, y: locationShape.boundingBox.midY)
            self.rotationAngle = blockShape.rotationAngle
            
            // Take into account the direction of travel of the train within
            // the block and rotate it 180 degree if necessary.
            if let block = layout.block(for: blockId), !block.trainNaturalDirection {
                self.rotationAngle += .pi
            }
        }
    }
    
    func draw(ctx: CGContext) {
        guard visible else {
            return
        }
        
        updatePosition()
        
        ctx.saveGState()
        
        ctx.addPath(path)
        ctx.setFillColor(shapeContext.trainColor(train.speed))
        ctx.fillPath()
                
        ctx.restoreGState()                
    }
    
    func inside(_ point: CGPoint) -> Bool {
        return path.contains(point)
    }    
    
}
