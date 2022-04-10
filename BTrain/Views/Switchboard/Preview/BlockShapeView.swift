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

struct BlockShapeView: View {
    
    let layout: Layout
    let category: Block.Category
    let shapeContext = ShapeContext()

    let viewSize = CGSize(width: 104, height: 34)
    
    var block: Block {
        let b = Block(name: "")
        b.category = category
        b.center = .init(x: viewSize.width/2, y: viewSize.height/2)
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


struct BlockShapeView_Previews: PreviewProvider {
    
    static let layout = LayoutLoop1().newLayout()
    
    static var previews: some View {
        ForEach(Block.Category.allCases, id:\.self) { category in
            BlockShapeView(layout: layout, category: category)
        }
    }
}
