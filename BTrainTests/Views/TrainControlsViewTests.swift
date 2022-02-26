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
import SwiftUI
import ViewInspector

@testable import BTrain

extension TrainControlActionsView: Inspectable { }
extension TrainControlRouteActionsView: Inspectable { }
extension TrainControlSetLocationSheet: Inspectable { }

class TrainControlsViewTests: RootViewTests {

    @Binding var error: String? = nil

    func testControlList() throws {
        doc.layout.trains[0].blockId = doc.layout.blockIds[0]
        
        let sut = TrainControlListView(layout: doc.layout, document: doc)
        
        let trainView = try sut.inspect().find(TrainControlContainerView.self)
        
        // Train Location
        let trainLocationView = try trainView.vStack().hStack(0).vStack(0).view(TrainControlLocationView.self, 1)
        
        let locationText = try trainLocationView.vStack().hStack(0).hStack(0).text(0)
        XCTAssertEqual(try locationText.string(), "Location:")
                
        // Train Controls
        let trainControlSpeedView = try trainView.vStack().hStack(0).vStack(0).view(TrainControlSpeedView.self, 2)
                        
        XCTAssertEqual(try trainControlSpeedView.vStack().hStack(0).hStack(1).text(1).string(), "0 kph")
        layout.trains[0].speed.requestedKph = 79
        XCTAssertEqual(try trainControlSpeedView.vStack().hStack(0).hStack(1).text(1).string(), "79/0 kph")

        // TrainRouteView
        let trainRouteView = try trainView.vStack().view(TrainControlRouteView.self, 1)
        let text = try trainRouteView.find(ViewType.Text.self)
        XCTAssertEqual(try text.string(), "Automatic")
    }
    
    func testRouteActions() throws {
        let layout = LayoutACreator().newLayout()
        let doc = LayoutDocument(layout: layout)
        let route = layout.routes[0]
        let train = layout.trains[0]
        
        let sut = TrainControlRouteActionsView(document: doc, train: train, route: route, error: $error)

        train.scheduling = .manual
        _ = try sut.inspect().find(button: "Start")
        XCTAssertThrowsError(try sut.inspect().find(button: "Stop"))
        XCTAssertThrowsError(try sut.inspect().find(button: "Finish"))

        train.scheduling = .automatic(finishing: false)
        _ = try sut.inspect().find(button: "Stop")
        var fb = try sut.inspect().find(button: "Finish")
        XCTAssertFalse(fb.isDisabled())
        XCTAssertThrowsError(try sut.inspect().find(button: "Start"))

        train.scheduling = .automatic(finishing: true)
        _ = try sut.inspect().find(button: "Stop")
        fb = try sut.inspect().find(button: "Finish")
        XCTAssertTrue(fb.isDisabled())
    }

    func testActions() throws {
        let sut = TrainControlActionsView(layout: doc.layout, document: doc)
        _ = try sut.inspect().find(button: "􀊋 Start All")
    }
    
    func testSetLocationSheet() throws {
        let sut = TrainControlSetLocationSheet(layout: layout, controller: doc.layoutController, train: layout.trains[0])
        XCTAssertNoThrow(try sut.inspect().find(button: "Set"))
    }

}
