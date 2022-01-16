//
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

extension TrainControlRouteActionsView: Inspectable { }

class TrainRouteControlViewTests: XCTestCase {

    @Binding var error: String? = nil
    
    func testLayout() throws {
        let layout = LayoutACreator().newLayout()
        let doc = LayoutDocument(layout: layout)
        let route = layout.routes[0]
        let train = layout.trains[0]
        
        let sut = TrainControlRouteActionsView(document: doc, train: train, route: route, error: $error)

        train.state = .stopped
        _ = try sut.inspect().find(button: "Start")
        XCTAssertThrowsError(try sut.inspect().find(button: "Stop"))
        XCTAssertThrowsError(try sut.inspect().find(button: "Finish"))

        train.state = .running
        _ = try sut.inspect().find(button: "Stop")
        var fb = try sut.inspect().find(button: "Finish")
        XCTAssertFalse(fb.isDisabled())
        XCTAssertThrowsError(try sut.inspect().find(button: "Start"))

        train.state = .finishing
        _ = try sut.inspect().find(button: "Stop")
        fb = try sut.inspect().find(button: "Finish")
        XCTAssertTrue(fb.isDisabled())
    }

}
