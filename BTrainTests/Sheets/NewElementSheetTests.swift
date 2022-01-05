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

extension NewBlockSheet: Inspectable { }
extension NewTurnoutSheet: Inspectable { }

class NewElementSheetTests: XCTestCase {

    func testNewBlockSheet() throws {
        let layout = Layout()
        let sut = NewBlockSheet(layout: layout)
        
        _ = try sut.inspect().find(text: "Name:")
        _ = try sut.inspect().find(button: "Cancel")
        _ = try sut.inspect().find(button: "OK")
    }

    func testNewTurnoutSheet() throws {
        let layout = Layout()
        let sut = NewTurnoutSheet(layout: layout)
        
        _ = try sut.inspect().find(text: "Name:")
        _ = try sut.inspect().find(button: "Cancel")
        _ = try sut.inspect().find(button: "OK")
    }
}
