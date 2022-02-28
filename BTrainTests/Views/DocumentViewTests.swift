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

extension WelcomeView: Inspectable { }
extension DocumentView: Inspectable { }
extension ConnectSheet: Inspectable { }
extension DiagnosticsSheet: Inspectable { }
extension ImportLayoutSheet: Inspectable { }

class DocumentViewTests: RootViewTests {

    func testMainView() throws {
        let sut = MainView(document: doc)
        
        doc.selectedView = .overview
        XCTAssertNoThrow(try sut.inspect().find(OverviewView.self))
        
        doc.selectedView = .trains
        XCTAssertThrowsError(try sut.inspect().find(OverviewView.self))
        XCTAssertNoThrow(try sut.inspect().find(TrainListView.self))
        
        doc.selectedView = .blocks
        XCTAssertThrowsError(try sut.inspect().find(TrainDetailsView.self))
        XCTAssertNoThrow(try sut.inspect().find(BlockListView.self))
        
        doc.selectedView = .turnouts
        XCTAssertThrowsError(try sut.inspect().find(BlockListView.self))
        XCTAssertNoThrow(try sut.inspect().find(TurnoutListView.self))

        doc.selectedView = .feedback
        XCTAssertThrowsError(try sut.inspect().find(TurnoutListView.self))
        XCTAssertNoThrow(try sut.inspect().find(FeedbackEditListView.self))
    }

    func testWelcome() throws {
        let sut = WelcomeView(document: doc)
        _ = try sut.inspect().find(button: "􀈷 New Document")
        _ = try sut.inspect().find(button: "􀉚 Use Predefined Layout")
    }
    
    func testDocumentView() throws {
        let sut = DocumentView(document: doc)
        sut.hideWelcomeScreen = true
        _ = try sut.inspect().find(MainView.self)
        
        sut.hideWelcomeScreen = false
        _ = try sut.inspect().find(WelcomeView.self)
    }
    
    @Binding var connectAlertShowing: Bool = true

    func testToolbarContent() {
        let layout = Layout()
        let doc = LayoutDocument(layout: layout)
        let sut = DocumentToolbarContent(document: doc, connectAlertShowing: $connectAlertShowing)
        XCTAssertNotNil(sut.body)
    }

    func testConnectSheet() throws {
        let sut = ConnectSheet(document: doc, onConnectTasks: doc.onConnectTasks)
        XCTAssertNoThrow(try sut.inspect().find(button: "Connect"))
        XCTAssertNoThrow(try sut.inspect().find(button: "Cancel"))
    }

    func testDiagnosticsSheet() throws {
        let sut = DiagnosticsSheet(layout: layout, options: .skipLengths)
        XCTAssertNoThrow(try sut.inspect().find(button: "OK"))
        XCTAssertNoThrow(try sut.inspect().find(text: "The layout is correct!"))
    }

    func testImportLayoutSheet() throws {
        let sut = ImportLayoutSheet(document: doc)
        _ = try sut.inspect().vStack().hStack(2).find(button: "Import")
    }

}
