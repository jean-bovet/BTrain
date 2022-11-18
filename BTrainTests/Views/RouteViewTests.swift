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

@testable import BTrain
import ViewInspector
import XCTest

extension RouteView: Inspectable {}
extension RouteListView: Inspectable {}
extension CenteredCustomView: Inspectable {}
extension CenteredLabelView: Inspectable {}

class RouteViewTests: XCTestCase {
    func testLayout() throws {
        let layout = LayoutLoop1().newLayout()
        let sut = RouteView(layout: layout, route: layout.routes[0])

        _ = try sut.inspect().find(text: "4 steps")
    }

    func testRouteListView() throws {
        let layout = LayoutLoop1().newLayout()
        let sut = RouteListView(layout: layout)

        _ = try sut.inspect().find(text: "2 routes")
        _ = try sut.inspect().find(text: "No Selected Route")
    }
}
