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

extension WizardSelectLayout: Inspectable { }
extension WizardSelectLocomotive: Inspectable { }

class NewLayoutWizardViewTests: RootViewTests {

    func testNewLayoutWizardView() throws {
        let doc = newDocument()
        let sut = NewLayoutWizardView(document: doc)
        _ = try sut.inspect().find(button: "Previous")
        _ = try sut.inspect().find(button: "Next")
    }

    func testWizardSelectLayout() throws {
        let doc = newDocument()
        let sut = WizardSelectLayout(selectedLayout: .constant(doc.layout.id))
        _ = try sut.inspect().find(text: "Select a Layout:")
    }
    
    func testWizardSelectLocomotive() throws {
        let doc = newDocument()
        let sut = WizardSelectLocomotive(document: doc, selectedTrains: .constant([doc.layout.trains[0].id]))
        _ = try sut.inspect().find(text: "Select one ore more locomotive:")
    }
    
    func testHelper() throws {
        let doc = newDocument()
        let helper = PredefinedLayoutHelper()
        try helper.load()
        helper.create(layoutId: doc.layout.id, trains: [doc.layout.trains[0].id], in: doc)
    }
}
