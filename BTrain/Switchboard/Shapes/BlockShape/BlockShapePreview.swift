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

import SwiftUI

/// This class is used exclusively to debug the rendering of a BlockShape without having to run BTrain entirely.
struct BlockShapePreview: View {
    
    @Environment(\.colorScheme) var colorScheme

    let doc: LayoutDocument
    let category: Block.Category
    let hasTrain: Bool
    
    var layout: Layout {
        doc.layout
    }
    
    var shapeContext: ShapeContext {
        let c = doc.switchboard.context
        c.darkMode = colorScheme == .dark
        c.trainIconManager = doc.trainIconManager
        return c
    }

    var viewSize: CGSize {
        return CGSize(width: 104*2, height: 34*2)
    }
    
    var block: Block {
        let b = Block(name: "Block")
        if hasTrain {
            b.trainInstance = .init(layout.trains[0].id, .next)
        }
        b.category = category
        b.center = .init(x: viewSize.width/2, y: viewSize.height/2)
        // TODO
//        b.rotationAngle = .pi/2
        return b
    }
    
    var shape: BlockShape {
        let shape = BlockShape(layout: layout, block: block, shapeContext: shapeContext)
        return shape
    }
    
    var body: some View {
        Canvas { context, size in
            context.withCGContext { context in
                shape.draw(ctx: context)
            }
        }.frame(width: viewSize.width, height: viewSize.height)
    }
    
}


struct BlockShapePreview_Previews: PreviewProvider {
    
    static func document(blockName: Bool, trainIcon: Bool, timeUntilRestart: Bool = false) -> LayoutDocument {
        let helper = PredefinedLayoutHelper()
        try! helper.load()
        if timeUntilRestart {
            helper.predefinedDocument?.layout.trains[0].timeUntilAutomaticRestart = 10
        }
        helper.predefinedDocument?.switchboard.context.showBlockName = blockName
        helper.predefinedDocument?.switchboard.context.showTrainIcon = trainIcon
        return helper.predefinedDocument!
    }

    static var previews: some View {
        HStack {
            VStack {
                BlockShapePreview(doc: document(blockName: true, trainIcon: true), category: .free, hasTrain: false)
                
                BlockShapePreview(doc: document(blockName: true, trainIcon: false), category: .free, hasTrain: true)
                BlockShapePreview(doc: document(blockName: true, trainIcon: false, timeUntilRestart: true), category: .free, hasTrain: true)

                BlockShapePreview(doc: document(blockName: false, trainIcon: false), category: .free, hasTrain: true)
                BlockShapePreview(doc: document(blockName: false, trainIcon: false, timeUntilRestart: true), category: .free, hasTrain: true)

                BlockShapePreview(doc: document(blockName: true, trainIcon: true), category: .free, hasTrain: true)
                BlockShapePreview(doc: document(blockName: true, trainIcon: true, timeUntilRestart: true), category: .free, hasTrain: true)

                BlockShapePreview(doc: document(blockName: false, trainIcon: true), category: .free, hasTrain: true)
                BlockShapePreview(doc: document(blockName: false, trainIcon: true, timeUntilRestart: true), category: .free, hasTrain: true)
            }
            VStack {
            }
        }
                
    }
}
