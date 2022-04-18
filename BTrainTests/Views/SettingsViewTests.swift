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

extension SettingsView: Inspectable { }

class SettingsViewTests: XCTestCase {

    func testSettings() throws {
        let sut = SettingsView()
        let t0 = try sut.inspect().tabView(0)

        XCTAssertEqual(try t0.form(0).tabItem().label(0).title().text(0).string(), "General")
        XCTAssertEqual(try t0.form(1).tabItem().label(0).title().text(0).string(), "Speed")
        XCTAssertEqual(try t0.form(2).tabItem().label(0).title().text(0).string(), "Routing")
        XCTAssertEqual(try t0.form(3).tabItem().label(0).title().text(0).string(), "Logging")
        XCTAssertEqual(try t0.form(4).tabItem().label(0).title().text(0).string(), "Advanced")
    }

}
