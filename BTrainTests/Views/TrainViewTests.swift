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

extension TrainIconView: Inspectable { }
extension SectionTitleView: Inspectable { }
extension TrainDetailsIconSectionView: Inspectable { }
extension UnitViewModifier: Inspectable { }
extension TrainDetailsGeometrySectionView: Inspectable { }
extension TrainDetailsReservationSectionView: Inspectable { }

class TrainViewTests: RootViewTests {
    
    func testStringValue() throws {
        let doc = newDocument()
        let sut = TrainListView(document: doc, layout: doc.layout)
        let value = try sut.inspect().hStack().vStack(0).hStack(1).text(0).string()
        XCTAssertEqual(value, "3 trains")
    }

    func testDetailsView() throws {
        let doc = newDocument()
        let layout = LayoutLoop1().newLayout()
        let t1 = layout.trains[0]
        
        let sut = TrainDetailsView(document: doc, train: t1)
        
        let geometrySection = try sut.inspect().find(TrainDetailsGeometrySectionView.self)
        _ = try geometrySection.find(text: "Wagons:")
        
        let reservationSection = try sut.inspect().find(TrainDetailsReservationSectionView.self)
        _ = try reservationSection.find(text: "Leading: 2")
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
