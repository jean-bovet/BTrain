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

extension TurnoutShapeView: Inspectable { }
extension TurnoutDetailsView: Inspectable { }

class TurnoutViewTests: RootViewTests {
    
    func testListView() throws {
        let doc = newDocument()
        let sut = TurnoutListView(doc: doc, layout: LayoutLoop2().newLayout())
        let value = try sut.inspect().hStack().vStack(0).hStack(1).text(0).string()
        XCTAssertEqual(value, "2 turnouts")
    }

    func testShapeView() throws {
        let doc = newDocument()
        let sut = TurnoutShapeView(layout: doc.layout, category: .singleLeft, requestedState: .straight, actualState: .straight)
        _ = sut.renderAsImage()!
        _ = try sut.inspect().canvas(0)
    }
    
    func testTurnoutDetailsView() throws {
        let doc = newDocument()
        let sut = TurnoutDetailsView(doc: doc, layout: doc.layout, turnout: Turnout.singleLeft())
        _ = try sut.inspect().find(text: "Protocol:")
    }

    func testTurnoutDetails2View() throws {
        let doc = newDocument()
        let sut = TurnoutDetailsView(doc: doc, layout: doc.layout, turnout: Turnout.doubleSlip())
        _ = try sut.inspect().find(text: "Protocol:")
    }

}
