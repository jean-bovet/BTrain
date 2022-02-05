//
//  RouteResolverTests.swift
//  BTrainTests
//
//  Created by Jean Bovet on 2/3/22.
//

import XCTest
@testable import BTrain

class RouteResolverTests: XCTestCase {

    func testResolveSimpleRoute() throws {
        let layout = LayoutHCreator().newLayout()
        let route = layout.routes[0]
        let train = layout.trains[0]
        
        let resolver = RouteResolver(layout: layout)
        let resolvedSteps = try resolver.resolve(steps: ArraySlice(route.steps), trainId: train.id)
        
        XCTAssertEqual(route.steps.map({$0.description}), ["A-Next", "B-Next", "C-Next", "D-Next", "E-Next"])
        XCTAssertEqual(resolvedSteps.map({$0.description}), ["A-Next", "AB-(0>1)", "B-Next", "C-Next", "D-Next", "DE-(1>0)", "E-Next"])
    }
}
