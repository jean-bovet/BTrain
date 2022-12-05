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
import SwiftUI
import ViewInspector

extension BlockAllFeedbacksView: Inspectable {}
extension BlockDetailsView: Inspectable {}
extension BlockShapeView: Inspectable {}
extension BlockFeedbacksView: Inspectable {}
extension BlockDirectionFeedbacksView: Inspectable {}
extension BlockFeedbackDirectionView: Inspectable {}
extension BlockSpeedView: Inspectable {}

class BlockViewTests: RootViewTests {
    func testListView() throws {
        let sut = BlockEditingView(layout: LayoutLoop2().newLayout())
        _ = try sut.inspect().find(text: "5 blocks")
    }

    func testBlockEditView() throws {
        let layout = LayoutLoop2().newLayout()
        let sut = BlockDetailsView(layout: layout, block: layout.blocks[0])
        let feedbacks = try sut.inspect().find(BlockFeedbacksView.self)
        _ = try feedbacks.find(text: "Previous Direction")
        _ = try feedbacks.find(text: "Next Direction")
    }

    func testBlockShapeView() throws {
        let sut = BlockShapeView(layout: Layout(), category: .free)
        _ = try sut.inspect().find(ViewType.Canvas.self)
        _ = sut.block
        _ = sut.shape
    }

    func testAllFeedbackView() throws {
        let layout = newLayout()
        let block = layout.blocks[0]
        let sut = BlockAllFeedbacksView(layout: layout, block: block)

        _ = try sut.inspect().find(button: "+")
        _ = try sut.inspect().find(button: "-")
        _ = try sut.inspect().find(button: "Auto Fill")
    }

    func testDirectionFeedbacksView() throws {
        let layout = newLayout()
        let block = layout.blocks[0]
        let sut = BlockDirectionFeedbacksView(layout: layout, direction: .next, block: block)
        _ = try sut.inspect().find(text: "Entry:")
    }

    func testBlockSpeedView() throws {
        let layout = newLayout()
        let sut = BlockSpeedView(block: layout.blocks[0])
        _ = try sut.inspect().find(text: "Braking:")
    }
}
