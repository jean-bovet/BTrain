// Copyright 2021 Jean Bovet
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

class TrainListViewTests: RootViewTests {
    
    func testList() throws {
        doc.layout.mutableTrains[0].blockId = doc.layout.blockIds[0]
        
        let sut = TrainListView(layout: doc.layout, document: doc)
        
        let trainView = try sut.inspect().find(TrainView.self)
        
        // Train Location
        let trainLocationView = try trainView.vStack().view(TrainLocationView.self, 0)
        
        let locationText = try trainLocationView.vStack().hStack(0).text(0)
        XCTAssertEqual(try locationText.string(), "Location: b1")
                
        // Train Controls
        let trainControlsView = try trainView.vStack().tupleView(1).view(TrainControlsView.self, 0)
                
        XCTAssertEqual(try trainControlsView.vStack().hStack(0).text(2).string(), "0 km/h")
        layout.mutableTrains[0].speed = 300
        XCTAssertEqual(try trainControlsView.vStack().hStack(0).text(2).string(), "300 km/h")

        // TrainRouteView
        let trainRouteView = try trainView.vStack().tupleView(1).view(TrainRouteView.self, 1)
        let text = try trainRouteView.find(ViewType.Text.self)
        XCTAssertEqual(try text.string(), "Automatic")
    }
    
}
