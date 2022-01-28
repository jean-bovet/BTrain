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

@testable import BTrain

extension TrainDetailsDecoderSectionView: Inspectable { }
extension TrainDetailsSpeedSectionView: Inspectable { }
extension TrainSpeedView: Inspectable { }
extension TrainIconView: Inspectable { }
extension SectionTitleView: Inspectable { }

class TrainViewTests: RootViewTests {
    
    func testStringValue() throws {
        let sut = TrainListView(document: doc, layout: doc.layout)
        let value = try sut.inspect().hStack().vStack(0).hStack(1).text(0).string()
        XCTAssertEqual(value, "2 trains")
    }

    func testSpeedView() throws {
        let sut = TrainSpeedView(trainSpeed: TrainSpeed(kph: 50, decoderType: .MFX))
        _ = try sut.inspect().hStack().canvas(1)
    }

    func testDetailsView() throws {
        let layout = LayoutACreator().newLayout()
        let t1 = layout.trains[0]
        
        let sut = TrainDetailsView(layout: layout, train: t1, trainIconManager: TrainIconManager(layout: layout))
        
        let decoderSection = try sut.inspect().find(TrainDetailsDecoderSectionView.self)
        _ = try decoderSection.find(text: "Type:")
        _ = try decoderSection.find(text: "MFX")
        _ = try decoderSection.find(text: "Address:")
        
        let speedSection = try sut.inspect().find(TrainDetailsSpeedSectionView.self)
        _ = try speedSection.find(text: "Max Speed:")
        // TODO
//        _ = try speedSection.find(TrainSpeedView.self)
    }
    
    func testIconView() throws {
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

    func testSectionTitleView() throws {
        let sut = SectionTitleView(label: "This is a section")
        _ = try sut.inspect().find(text: "This is a section")
    }

}
