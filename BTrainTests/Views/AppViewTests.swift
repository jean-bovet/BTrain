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

class AppViewTests: RootViewTests {

    func testMainView() throws {
        let previousValue = doc.selectedView
        
        let sut = AppView(document: doc)
        
        doc.selectedView = .switchboard
        XCTAssertNoThrow(try sut.inspect().find(OverviewView.self))
        
        doc.selectedView = .locomotives
        XCTAssertThrowsError(try sut.inspect().find(OverviewView.self))
        XCTAssertNoThrow(try sut.inspect().find(TrainEditListView.self))
        
        doc.selectedView = .blocks
        XCTAssertThrowsError(try sut.inspect().find(TrainEditListView.self))
        XCTAssertNoThrow(try sut.inspect().find(BlockEditListView.self))
        
        doc.selectedView = .turnouts
        XCTAssertThrowsError(try sut.inspect().find(BlockEditListView.self))
        XCTAssertNoThrow(try sut.inspect().find(TurnoutEditListView.self))

        doc.selectedView = .feedback
        XCTAssertThrowsError(try sut.inspect().find(TurnoutEditListView.self))
        XCTAssertNoThrow(try sut.inspect().find(FeedbackEditListView.self))

        doc.selectedView = .feedbackMonitor
        XCTAssertThrowsError(try sut.inspect().find(FeedbackEditListView.self))
        XCTAssertNoThrow(try sut.inspect().find(FeedbackMonitorView.self))
        
        doc.selectedView = previousValue
    }

}
