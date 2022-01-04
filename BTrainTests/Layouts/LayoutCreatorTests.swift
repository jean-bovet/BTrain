//
//  LayoutCreatorTests.swift
//  BTrainTests
//
//  Created by Jean Bovet on 1/4/22.
//

import XCTest

@testable import BTrain

class LayoutCreatorTests: XCTestCase {

    func testEmptyLayout() {
        let c = LayoutBlankCreator()
        XCTAssertEqual(c.name, "New Layout")
        XCTAssertNotNil(c.newLayout())
    }

    func testLayoutA() {
        let c = LayoutACreator()
        XCTAssertEqual(c.name, "Layout A")
        XCTAssertNotNil(c.newLayout())
    }

}
