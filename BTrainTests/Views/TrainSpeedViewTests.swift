//
//  TrainSpeedViewTests.swift
//  BTrainTests
//
//  Created by Jean Bovet on 1/15/22.
//

import XCTest

@testable import BTrain
import ViewInspector

extension TrainSpeedView: Inspectable { }

class TrainSpeedViewTests: XCTestCase {
    
    func testLayout() throws {
        let sut = TrainSpeedView(trainSpeed: TrainSpeed(kph: 50, decoderType: .MFX))
        _ = try sut.inspect().hStack().canvas(1)
    }
    
}
