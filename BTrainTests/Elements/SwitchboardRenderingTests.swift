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

import XCTest
@testable import BTrain

class SwitchboardRenderingTests: XCTestCase {

    var nsContext: NSGraphicsContext!
    
    override func setUp() {
        nsContext = NSGraphicsContext(attributes: [.destination:NSGraphicsContext.RepresentationFormatName.pdf])!
    }
    
    func testDrawBoard() {
        let layout = LayoutACreator().newLayout()
        let context = ShapeContext()
        let provider = ShapeProvider(layout: layout, context: context)

        provider.blockShapes[0].selected = true
        
        let renderer = SwitchBoardRenderer(provider: provider, shapeContext: context)
        renderer.draw(context: nsContext.cgContext)
    }
    
    func testDrawText() {
        let layout = LayoutACreator().newLayout()
        let context = ShapeContext()
        let provider = ShapeProvider(layout: layout, context: context)
      
        let block = provider.blockShapes[0]
        
        block.drawText(ctx: nsContext.cgContext, center: .zero, text: "Hello", color: .black, fontSize: 12.0)
    }

}
