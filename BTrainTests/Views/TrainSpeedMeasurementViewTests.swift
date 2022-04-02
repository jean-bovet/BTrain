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

extension TrainSpeedMeasurementsView: Inspectable { }
extension TrainSpeedMeasureControlsView: Inspectable { }

class TrainSpeedMeasurementViewTests: RootViewTests {

    func testMeasurementsView() throws {
        let sut = TrainSpeedMeasurementsView(document: doc, layout: doc.layout)
        _ = try sut.inspect().find(text: "Locomotive:")
    }

    func testMeasureControlsView() throws {
        let sut = TrainSpeedMeasureControlsView(document: doc, train: doc.layout.trains[0], speedEntries: .constant([]), feedbackA: "a", feedbackB: "b", feedbackC: "c", distanceAB: .constant(10), distanceBC: .constant(20), running: .constant(false), currentSpeedEntry: .constant(nil))
        _ = try sut.inspect().find(text: "Measure")
    }

}
