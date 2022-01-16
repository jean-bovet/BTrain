//
//  TrainDetailsViewTests.swift
//  BTrainTests
//
//  Created by Jean Bovet on 1/15/22.
//

import XCTest

@testable import BTrain
import ViewInspector

class TrainDetailsViewTests: XCTestCase {
    
    func testLayout() throws {
        let layout = LayoutACreator().newLayout()
        let t1 = layout.trains[0]
        
        let sut = TrainDetailsView(layout: layout, train: t1, trainIconManager: TrainIconManager(layout: layout))
        _ = try sut.inspect().find(text: "Decoder:")
        _ = try sut.inspect().find(text: "MFX")
        
        _ = try sut.inspect().find(text: "Address:")
        _ = try sut.inspect().find(TrainSpeedView.self)
    }
    
}
