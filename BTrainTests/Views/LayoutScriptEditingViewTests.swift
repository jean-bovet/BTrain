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

extension LayoutScriptEditingView: Inspectable { }

final class LayoutScriptEditingViewTests: XCTestCase {

    func testAddNewScript() throws {
        let doc = LayoutDocument(layout: Layout())
        let layout = doc.layout
        let sut = LayoutScriptEditingView(doc: doc, layout: layout)
        
        XCTAssertEqual(layout.layoutScripts.elements.count, 0)
        
        let addButton = try sut.inspect().find(button: "+")
        try addButton.tap()

        XCTAssertEqual(layout.layoutScripts.elements.count, 1)
        XCTAssertEqual(layout.layoutScripts[0].name, "New Script")

        let deleteButton = try sut.inspect().find(button: "-")
        XCTAssertTrue(deleteButton.isDisabled())

        let duplicateButton = try sut.inspect().find(button: "􀐅")
        XCTAssertTrue(duplicateButton.isDisabled())
    }

}
