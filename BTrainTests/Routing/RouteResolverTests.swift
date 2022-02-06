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
