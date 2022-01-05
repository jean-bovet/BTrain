// Copyright 2021 Jean Bovet
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

extension BlockFeedbackView: Inspectable { }
extension BlockEditView: Inspectable { }

class BlockEditListViewTests: RootViewTests {
    
    func testLayout() throws {
        let sut = BlockEditListView(layout: LayoutCCreator().newLayout())
        let value = try sut.inspect().vStack().hStack(0).vStack(0).hStack(1).text(0).string()
        XCTAssertEqual(value, "5 blocks")
        
        // TODO: how to traverse a Table?
//        let tiv = try sut.inspect().findAll(TrainInstanceView.self).first!
//        try tiv.find(text: "Rail 2000")
//        try sut.inspect().vStack().view(Table<Value, Rows: TableRowContent, Columns: TableColumnContent>.self, 0).view(TableColumn.sef, 3).view(TrainInstanceView.self)
//        try sut.inspect().find(BlockFeedbackView.self)
    }
    
    func testBlockEditView() throws {
        let layout = LayoutCCreator().newLayout()
        let sut = BlockEditView(layout: layout, block: layout.blocks[0])
        XCTAssertEqual(try sut.inspect().vStack().groupBox(1).labelView().text().string(), "Feedbacks")
    }
}
