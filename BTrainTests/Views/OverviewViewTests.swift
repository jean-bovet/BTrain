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

extension SwitchboardRuntimeErrorView: Inspectable { }

class OverviewViewTests: RootViewTests {

    func testMainView() throws {
        let sut = OverviewView(document: doc)
        XCTAssertNoThrow(try sut.inspect().hStack().vStack(0).view(TrainControlListView.self, 0))
        XCTAssertThrowsError(try sut.inspect().hStack().vStack(0).view(SimulatorView.self, 1))
        XCTAssertNoThrow(try sut.inspect().hStack().view(SwitchboardContainerView.self, 1))
    }
    
    func testOverviewSwitchboardView() throws {
        let sut = SwitchboardContainerView(layout: doc.layout, layoutController: doc.layoutController, document: doc, switchboard: doc.switchboard, state: doc.switchboard.state)
        XCTAssertNoThrow(try sut.inspect().vStack().vStack(0).view(SwitchboardEditControlsView.self, 0))
        XCTAssertNoThrow(try sut.inspect().vStack().vStack(0).scrollView(1).view(SwitchBoardView.self))
    }
    
    func testLayoutRuntimeError() throws {
        let text = "Unknown feedback detected!"
        let sut = SwitchboardRuntimeErrorView(debugger: LayoutControllerDebugger(layout: Layout()), error: .constant(text))
        _ = try sut.inspect().find(button: "OK")
        _ = try sut.inspect().find(text: "\(text)")
    }
}
