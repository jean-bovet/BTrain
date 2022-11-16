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
extension TrainControlSetLocationSheet: Inspectable { }
extension TrainControlStateView: Inspectable { }

extension SpeedSlider: Inspectable { }
extension CustomSlider: Inspectable { }

class TrainControlsViewTests: RootViewTests {

    func testControlList() throws {
        let doc = newDocument()
        doc.layout.trains[0].blockId = doc.layout.blocks[0].id
        
        let sut = TrainControlListView(layout: doc.layout, document: doc, pinnedTrainIds: .constant([]))
        
        let trainView = try sut.inspect().find(TrainControlContainerView.self)
        
        // Train Location
        let trainLocationView = try trainView.vStack().hStack(0).vStack(0).view(TrainControlLocationView.self, 1)
        
        let locationText = try trainLocationView.vStack().hStack(0).hStack(0).text(0)
        XCTAssertEqual(try locationText.string(), "Location:")
                
        // Train Controls
        let trainControlSpeedView = try trainView.find(TrainControlSpeedView.self)
                        
        _ = try trainControlSpeedView.find(text: "0")
        doc.layout.locomotives[0].speed.requestedKph = 79
        _ = try trainControlSpeedView.find(text: "79")

        // TrainRouteView
        let trainRouteView = try trainView.find(TrainControlRouteView.self)
        let picker = try trainRouteView.find(ViewType.Picker.self)
        XCTAssertEqual(try picker.text(0).string(), "Automatic")
    }
    
    func testRouteActions() throws {
        let layout = LayoutLoop1().newLayout()
        let doc = LayoutDocument(layout: layout)
        doc.connected = true
        let train = layout.trains[0]
        
        let sut = TrainControlRouteView(document: doc, train: train, trainRuntimeError: .constant(nil))

        train.scheduling = .unmanaged
        _ = try sut.inspect().find(button: "Start")
        XCTAssertThrowsError(try sut.inspect().find(button: "Stop"))
        XCTAssertThrowsError(try sut.inspect().find(button: "Finish"))

        train.scheduling = .managed
        _ = try sut.inspect().find(button: "Stop")
        var fb = try sut.inspect().find(button: "Finish")
        XCTAssertFalse(fb.isDisabled())
        XCTAssertThrowsError(try sut.inspect().find(button: "Start"))

        train.scheduling = .finishManaged
        _ = try sut.inspect().find(button: "Stop")
        fb = try sut.inspect().find(button: "Finish")
        XCTAssertTrue(fb.isDisabled())
    }

    func testActions() throws {
        let doc = newDocument()
        let sut = TrainControlActionsView(document: doc, layout: doc.layout, filterRunningTrains: .constant(true))
        _ = try sut.inspect().find(button: "􀊋 Start All")
    }
    
    func testSetLocationSheet() throws {
        let doc = newDocument()
        let sut = TrainControlSetLocationSheet(layout: doc.layout, controller: doc.layoutController, train: doc.layout.trains[0])
        XCTAssertNoThrow(try sut.inspect().find(button: "Set"))
    }

    func testTrainControlStateView() throws {
        let doc = newDocument()
        let train = doc.layout.trains[0]
        let sut = TrainControlStateView(train: train, trainRuntimeError: .constant("Error!"))
        _ = try sut.inspect().find(button: "􀇾")
    }
}
