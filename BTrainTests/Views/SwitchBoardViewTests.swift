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
import ViewInspector
import SwiftUI

@testable import BTrain

extension Canvas: Inspectable { }
extension SwitchboardEditControlsView: Inspectable { }
extension NewBlockSheet: Inspectable { }
extension NewTurnoutSheet: Inspectable { }

class SwitchBoardViewTests: XCTestCase {

    func testSwitchboardView() throws {
        let layout = LayoutACreator().newLayout()
        let context = ShapeContext()
        let provider = ShapeProvider(layout: layout, context: context)
        let switchboard = SwitchBoard(layout: layout, provider: provider, context: context)
        let coordinator = LayoutController(layout: layout, interface: nil)
        let v = SwitchBoardView(switchboard: switchboard, state: switchboard.state, layout: layout, layoutController: coordinator)
        
        let canvas = try v.inspect().view(Canvas<SwitchBoardView>.self)
        
        let gesture = try canvas.gesture(DragGesture.self)
        try gesture.callOnChanged(value: DragGesture.Value(time: Date(), location: .zero, startLocation: .zero, velocity: .zero))
        try gesture.callOnEnded(value: DragGesture.Value(time: Date(), location: .zero, startLocation: .zero, velocity: .zero))
    }

    func testEditControls() throws {
        let layout = LayoutACreator().newLayout()
        let doc = LayoutDocument(layout: layout)
        let state = doc.switchboard.state
        
        let sut = SwitchboardEditControlsView(layout: layout, state: state, document: doc, switchboard: doc.switchboard)
        
        state.editable = false
        
        XCTAssertThrowsError(_ = try sut.inspect().find(button: "􀅼 Block"))

        state.editable = true
        
        _ = try sut.inspect().find(button: "􀅼 Block")
    }
    
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
