//
//  SettingsViewTests.swift
//  BTrainTests
//
//  Created by Jean Bovet on 1/4/22.
//

import XCTest

@testable import BTrain
import ViewInspector

extension SettingsView: Inspectable { }

class SettingsViewTests: XCTestCase {

    func testSettings() throws {
        let sut = SettingsView()
        let t0 = try sut.inspect().tabView(0)

        XCTAssertEqual(try t0.form(0).tabItem().label(0).title().text(0).string(), "General")
        XCTAssertEqual(try t0.form(1).tabItem().label(0).title().text(0).string(), "Advanced")
    }

}
