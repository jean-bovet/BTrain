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
        let t1 = layout.addTrain(Train(uuid: "16390"))
        
        let tim = TrainIconManager(layout: layout)

        let sut = TrainIconView(trainIconManager: tim, train: t1, size: .medium)
        _ = try sut.inspect().hStack().shape(0)

        let url = Bundle(for: LayoutDocument.self).url(forResource: "Predefined", withExtension: "btrain")!
        
        let fw = try FileWrapper(url: url, options: [])
        XCTAssertNotNil(try fw.layout())
        tim.setIcons(try fw.icons())

        _ = try sut.inspect().hStack().image(0)
        
        let image = tim.imageFor(train: t1)!
        XCTAssertNotNil(image.jpegData())
    }
    
}
