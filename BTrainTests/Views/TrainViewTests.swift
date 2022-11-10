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
import AppKit

@testable import BTrain

extension LocDetailsDecoderSectionView: Inspectable { }
extension LocDetailsSpeedSectionView: Inspectable { }
extension TrainSpeedView: Inspectable { }
extension TrainIconView: Inspectable { }
extension SectionTitleView: Inspectable { }
extension TrainSpeedGraphView: Inspectable { }
extension TrainSpeedColumnView: Inspectable { }
extension TrainSpeedTimingFunctionView: Inspectable { }
extension TrainDetailsIconSectionView: Inspectable { }
extension UnitViewModifier: Inspectable { }

class TrainViewTests: RootViewTests {
    
    func testStringValue() throws {
        let doc = newDocument()
        let sut = TrainListView(document: doc, layout: doc.layout)
        let value = try sut.inspect().hStack().vStack(0).hStack(1).text(0).string()
        XCTAssertEqual(value, "3 trains")
    }

    func testSpeedView() throws {
        let doc = newDocument()
        let sut = TrainSpeedView(document: doc, loc: doc.layout.locomotives[0], trainSpeed: LocomotiveSpeed(kph: 50, decoderType: .MFX))
        _ = try sut.inspect().vStack().hStack(0).view(TrainSpeedGraphView.self, 1).canvas(0)
    }

    func testSpeedGraphView() throws {
        let sut = TrainSpeedGraphView(trainSpeed: .init(kph: 10, decoderType: .DCC))
            .frame(minWidth: 100, minHeight: 100)
        let image = sut.renderAsImage()!
        XCTAssertEqual(image.size, .init(width: 100, height: 100))
        _ = try sut.inspect().find(TrainSpeedGraphView.self).canvas(0)
    }
    
    func testSpeedColumnView() throws {
        let sut = TrainSpeedColumnView(selection: .constant([]), currentSpeedEntry: .constant(nil), trainSpeed: LocomotiveSpeed(kph: 0, decoderType: .MFX))
        _ = try sut.inspect().find(button: "􁂥")
    }

    func testSpeedTimingFunctionView() throws {
        let sut = TrainSpeedTimingFunctionView(tf: .init(fromSteps: 0, toSteps: 10, timeIncrement: 100, stepIncrement: 4, type: .bezier))
        _ = sut.renderAsImage()!
        _ = try sut.inspect().canvas(0)
    }

    func testDetailsView() throws {
        let doc = newDocument()
        let layout = LayoutLoop1().newLayout()
        let t1 = layout.trains[0]
        
        let sut = TrainDetailsView(document: doc, train: t1)
        
        let decoderSection = try sut.inspect().find(LocDetailsDecoderSectionView.self)
        _ = try decoderSection.find(text: "Type:")
        _ = try decoderSection.find(text: "MFX")
        _ = try decoderSection.find(text: "Address:")
        
        let speedSection = try sut.inspect().find(LocDetailsSpeedSectionView.self)
        _ = try speedSection.find(text: "Max Speed:")
    }
  
    // TODO: with locomotive icon details
//    func testIconSectionView() throws {
//        let doc = newDocument()
//        let sut = TrainDetailsIconSectionView(train: doc.layout.trains[0], trainIconManager: doc.trainIconManager)
//        _ = try sut.inspect().find(text: "Icon")
//    }
    
    func testIconView() throws {
        let layout = LayoutLoop1().newLayout()
        let loc = layout.addLocomotive(Locomotive(uuid: "16390"))
        
        let tim = LocomotiveIconManager()

        let sut = TrainIconView(locomotiveIconManager: tim, loc: loc, size: .medium, hideIfNotDefined: false)
        _ = try sut.inspect().hStack().shape(0)

        let url = Bundle(for: LayoutDocument.self).url(forResource: "Predefined", withExtension: "btrain")!
        
        let fw = try FileWrapper(url: url, options: [])
        XCTAssertNotNil(try fw.layout())
        tim.setIcons(try fw.locomotiveIcons())

        _ = try sut.inspect().hStack().image(0)
        
        let image = tim.icon(for: loc.id)!
        XCTAssertNotNil(image.pngData())
    }

    func testUnitView() throws {
        let sut = TextField("Distance", text: .constant("")).unitStyle("mm")
        _ = try sut.inspect().find(text: "Distance")
        _ = try sut.inspect().find(text: "mm")
    }
    
    func testSectionTitleView() throws {
        let sut = SectionTitleView(label: "This is a section")
        _ = try sut.inspect().find(text: "This is a section")
    }

}
