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
import UniformTypeIdentifiers

@testable import BTrain

class LayoutDocumentTests: XCTestCase {
    
    func testReadPackageFile() throws {
        let url = Bundle(for: LayoutDocument.self).url(forResource: "Predefined", withExtension: "btrain")!
        
        let fw = try FileWrapper(url: url, options: [])

        let doc = try LayoutDocument(contentType: LayoutDocument.packageType, file: fw)
        let diag = LayoutDiagnostic(layout: doc.layout)
        let errors = try diag.check(.skipLengths)
        XCTAssertEqual(errors.count, 0)
        
        let snapshot = try doc.snapshot(contentType: LayoutDocument.packageType)
        _ = try doc.fileWrapper(snapshot: snapshot, contentType: LayoutDocument.packageType)
    }
    
    func testReadJSONFile() throws {
        guard let url = Bundle(for: type(of: self )).url(forResource: "Layout", withExtension: "json") else {
            XCTFail("Unable to find the Layout.json file")
            return
        }

        let fw = try FileWrapper(url: url, options: [])

        let doc = try LayoutDocument(contentType: .json, file: fw)
        let diag = LayoutDiagnostic(layout: doc.layout)
        let errors = try diag.check(.skipLengths)
        XCTAssertEqual(errors.count, 0)
        
        let snapshot = try doc.snapshot(contentType: .json)
        _ = try doc.fileWrapper(snapshot: snapshot, contentType: .json)
    }
    
    func testUXCommands() throws {
        let layout = LayoutACreator().newLayout()
        let doc = LayoutDocument(layout: layout)

        connectToSimulator(doc: doc)
        defer {
            disconnectFromSimulator(doc: doc)
        }

        let train = layout.trains[0]
        let route = layout.routes[0]
        train.blockId = route.steps[0].blockId
        layout.block(for: train.blockId!)?.train = .init(train.id, .next)
        
        try doc.start(train: train.id, withRoute: route.id, destination: nil)
        try doc.stop(train: train)
    }
    
    static weak var memoryLeakLayout: Layout?
    
    func testMemoryLeak() {
        var doc: LayoutDocument? = LayoutDocument(layout: LayoutACreator().newLayout())
        LayoutDocumentTests.memoryLeakLayout = doc!.layout
        XCTAssertNotNil(LayoutDocumentTests.memoryLeakLayout)
        doc = nil
        XCTAssertNil(LayoutDocumentTests.memoryLeakLayout)
    }
    
    func testOnConnectTasks() throws {
        let doc = LayoutDocument(layout: LayoutACreator().newLayout())
        let t = LayoutOnConnectTasks(layout: doc.layout, layoutController: doc.layoutController, interface: doc.interface)
        
        connectToSimulator(doc: doc)
        defer {
            disconnectFromSimulator(doc: doc)
        }
        
        let expectation = expectation(description: "Completion")
        t.performOnConnectTasks(activateTurnouts: true) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
    }
    
    private func connectToSimulator(doc: LayoutDocument) {
        let e = expectation(description: "connect")
        doc.connectToSimulator(enable: false) { error in
            e.fulfill()
        }
        waitForExpectations(timeout: 0.250, handler: nil)
        
        doc.enable() {}
    }
    
    private func disconnectFromSimulator(doc: LayoutDocument) {
        doc.disable() {}
        doc.disconnect()
    }
}
