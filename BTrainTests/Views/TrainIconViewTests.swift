//
//  TrainIconViewTests.swift
//  BTrainTests
//
//  Created by Jean Bovet on 1/15/22.
//

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
