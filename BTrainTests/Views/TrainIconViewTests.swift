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

extension TrainIconView: Inspectable { }

class TrainIconViewTests: XCTestCase {
    
    func testLayout() throws {
        let layout = LayoutACreator().newLayout()
        let t1 = layout.trains[0]

        // TODO: not able to test bookmark because unit tests are not sandboxed
        let tim = TrainIconManager(layout: layout)
//        let url = Bundle(for: TrainIconViewTests.self).urlForImageResource("460-sbb-cff")!
//        tim.setIcon(url, toTrain: t1)
//        XCTAssertNotNil(t1.iconUrlData)
        
        let sut = TrainIconView(trainIconManager: tim, train: t1, size: .medium)
        _ = try sut.inspect().hStack().shape(0)
    }
    
}
