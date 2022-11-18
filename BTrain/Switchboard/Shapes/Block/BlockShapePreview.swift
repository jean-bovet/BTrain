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
    let angle: CGFloat
    let settings: BlockShapePreviewSettings

    var layout: Layout {
        doc.layout
    }

    var shapeContext: ShapeContext {
        let c = doc.switchboard.context
        c.darkMode = colorScheme == .dark
        c.locomotiveIconManager = doc.locomotiveIconManager
        return c
    }

    var viewSize: CGSize {
        switch angle {
        case 0, .pi:
            return CGSize(width: 200, height: 68)
        case .pi / 4, .pi / 4 * 3, .pi / 4 * 5, .pi / 4 * 7:
            return CGSize(width: 200, height: 200)
        case .pi / 2, .pi / 4 * 6:
            return CGSize(width: 68, height: 200)
        default:
            return .zero
        }
    }

    var block: Block {
        let b = Block(name: "Block")
        if settings.hasTrain {
            b.trainInstance = .init(layout.trains[0].id, .next)
        }
        doc.layout.trains[0].timeUntilAutomaticRestart = settings.timeUntilRestart ? 10 : 0
        doc.switchboard.context.showBlockName = settings.blockName
        doc.switchboard.context.showTrainIcon = settings.trainIcon

        b.category = category
        b.center = .init(x: viewSize.width / 2, y: viewSize.height / 2)
        b.rotationAngle = angle
        return b
    }

    var shape: BlockShape {
        let shape = BlockShape(layout: layout, block: block, shapeContext: shapeContext)
        return shape
    }

    var body: some View {
        Canvas { context, _ in
            context.withCGContext { context in
                shape.draw(ctx: context)
            }
        }.frame(width: viewSize.width, height: viewSize.height)
    }
}

struct BlockShapePreviewSettings: Hashable {
    let hasTrain: Bool
    let blockName: Bool
    let trainIcon: Bool
    let timeUntilRestart: Bool
}

struct BlockShapesPreview: View {
    let angles: [CGFloat] = [0, .pi / 4, .pi / 4 * 2, .pi / 4 * 3, .pi / 4 * 4, .pi / 4 * 5, .pi / 4 * 6, .pi / 4 * 7]

    let settings: [BlockShapePreviewSettings]
    let doc: LayoutDocument

    var body: some View {
        VStack {
            ForEach(settings, id: \.self) { settings in
                HStack {
                    ForEach(angles, id: \.self) { angle in
                        BlockShapePreview(doc: doc, category: .free, angle: angle, settings: settings)
                    }
                }
            }
        }
    }
}

struct BlockShapePreview_Previews: PreviewProvider {
    static func settings(trainIcon: Bool) -> [BlockShapePreviewSettings] {
        [
            .init(hasTrain: false, blockName: true, trainIcon: trainIcon, timeUntilRestart: false),
            .init(hasTrain: true, blockName: true, trainIcon: trainIcon, timeUntilRestart: false),
            .init(hasTrain: true, blockName: true, trainIcon: trainIcon, timeUntilRestart: true),
            .init(hasTrain: true, blockName: false, trainIcon: trainIcon, timeUntilRestart: false),
            .init(hasTrain: true, blockName: false, trainIcon: trainIcon, timeUntilRestart: true),
        ]
    }

    static func document() -> LayoutDocument {
        let helper = PredefinedLayoutHelper()
        try! helper.load()
        return helper.predefinedDocument!
    }

    static var previews: some View {
        BlockShapesPreview(settings: settings(trainIcon: true), doc: document())
        BlockShapesPreview(settings: settings(trainIcon: false), doc: document())
    }
}
