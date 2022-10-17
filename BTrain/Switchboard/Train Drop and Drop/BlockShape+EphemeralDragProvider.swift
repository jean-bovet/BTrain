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

import AppKit
import GraphicsRenderer

extension BlockShape: EphemeralDragProvider {
    
    func draggableShape(at location: CGPoint) -> EphemeralDraggableShape? {
        guard inside(location) || insideLabels(location) else {
            return nil
        }
        
        guard let train = train, train.scheduling == .unmanaged && block.blockContainsLocomotive else {
            return nil
        }
        
        let imageSize = CGSize(width: bounds.width * 4, height: bounds.height * 4)
        let image: NSImage = ImageRenderer(size: imageSize).image { context in
            let center = self.center
            self.center = .init(x: imageSize.width/2, y: imageSize.height/2)
            
            let ctx = context.cgContext
            ctx.with {
                drawTrainParts(ctx: ctx, lineBetweenParts: true)
            }
            
            ctx.with {
                drawLabels(ctx: ctx, forceHideBlockName: true)
            }
            
            self.center = center
        }
        return EphemeralDraggedTrainShape(trainId: train.id, image: image, center: center)
    }
    
    private func insideLabels(_ location: CGPoint) -> Bool {
        for path in labelPaths {
            if path.inside(location) {
                return true
            }
        }
        return false
    }
    
}
