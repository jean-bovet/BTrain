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
import ViewInspector
import SwiftUI

extension BlockAllFeedbacksView: Inspectable { }
extension BlockDetailsView: Inspectable { }
extension BlockShapeView: Inspectable { }
extension BlockFeedbacksView: Inspectable { }

class BlockListViewTests: RootViewTests {
    
    func testLayout() throws {
        let sut = BlockListView(layout: LayoutCCreator().newLayout())
        let value = try sut.inspect().vStack().hStack(0).vStack(0).hStack(1).text(0).string()
        XCTAssertEqual(value, "5 blocks")
    }
    
    func testBlockEditView() throws {
        let layout = LayoutCCreator().newLayout()
        let sut = BlockDetailsView(layout: layout, block: layout.blocks[0])
        let feedbacks = try sut.inspect().find(BlockFeedbacksView.self)
        _ = try feedbacks.find(text: "Previous Direction")
        _ = try feedbacks.find(text: "Next Direction")
    }
    
    func testBlockShapeView() throws {
        let sut = BlockShapeView(layout: Layout(), category: .free)
        _ = try sut.inspect().find(ViewType.Canvas)
        _ = sut.block
        _ = sut.shape
    }
}
