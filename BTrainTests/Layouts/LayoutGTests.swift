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

class LayoutGTests: RootLayoutTests {

    override var layoutID: Identifier<Layout>? {
        return LayoutGCreator.id
    }

    func testLayout() {
        XCTAssertEqual(layout.blockMap.count, 8)
    }
    
    func testEntryBrakeStopFeedbacks() throws {
        let layout = LayoutECreator().newLayout()
        layout.strictRouteFeedbackStrategy = false
                
        let train = layout.trains[0]
        
        let b3 = layout.block(for: Identifier<Block>(uuid: "b3"))!
        b3.brakeFeedbackNext = Identifier<Feedback>(uuid: "fb3.1")
        b3.stopFeedbackNext = Identifier<Feedback>(uuid: "fb3.2")

        XCTAssertEqual(b3.entryFeedback(for: .next), Identifier<Feedback>(uuid: "fb3.1"))
        XCTAssertEqual(b3.brakeFeedback(for: .next), Identifier<Feedback>(uuid: "fb3.1"))
        XCTAssertEqual(b3.stopFeedback(for: .next), Identifier<Feedback>(uuid: "fb3.2"))

        var p = try setup(layout: layout, fromBlockId: "s1", route: layout.routes[0])

        XCTAssertEqual(train.scheduling, .running)
        XCTAssertEqual(train.state, .running)

        try p.assert("0: {r0{s1 🚂0 ≏ }} <r0<t1,l>> <r0<t2,s>> [r0[b1 ≏ ]] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ≏ ] <t5> <t6> {s1 🚂0 ≏ }")
        try p.assert("0: {s1 ≏ } <t1,l> <t2,s> [r0[b1 ≡ 🚂0 ]] <r0<t3>> [r0[b2 ≏ ]] <t4> [b3 ≏ ≏ ≏ ] <t5> <t6> {s1 ≏ }")
        try p.assert("0: {s1 ≏ } <t1,l> <t2,s> [b1 ≏ ] <t3> [r0[b2 ≡ 🚂0 ]] <r0<t4>> [r0[b3 ≏ ≏ ≏ ]] <t5> <t6> {s1 ≏ }")

        // Let's put another train in s1
        layout.reserve("s1", with: "1", direction: .next)

        try p.assert("0: {r1{s1 ≏ }} <t1,l> <t2,s> [b1 ≏ ] <t3> [r0[b2 ≏ 🚂0 ]] <r0<t4>> [r0[b3 ≏ ≏ ≏ ]] <t5> <t6> {r1{s1 ≏ }}")
        try p.assert("0: {r1{s1 ≏ }} <t1,l> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≡ 🟨🚂0 ≏ ≏ ]] <t5> <t6> {r1{s1 ≏ }}")
        XCTAssertEqual(train.state, .braking)
        
        try p.assert("0: {r1{s1 ≏ }} <t1,l> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≏ ≡ 🛑🚂0 ≏ ]] <t5> <t6> {r1{s1 ≏ }}")
        
        XCTAssertEqual(train.scheduling, .running)
        XCTAssertEqual(train.state, .stopped)
        
        // Free s1 so the train finishes its route
        layout.free("s1")
        
        try p.assert("0: {r0{s1 ≏ }} <t1,l> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≏ ≏ 🚂0 ≏ ]] <r0<t5>> <r0<t6,r>> {r0{s1 ≏ }}")
        try p.assert("0: {r0{s1 ≏ }} <t1,l> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [r0[b3 ≏ ≏ ≡ 🚂0 ]] <r0<t5>> <r0<t6,r>> {r0{s1 ≏ }}")
        try p.assert("0: {r0{s1 ≡ 🛑🚂0 }} <t1,l> <t2,s> [b1 ≏ ] <t3> [b2 ≏ ] <t4> [b3 ≏ ≏ ≏ ] <t5> <t6,r> {r0{s1 ≡ 🛑🚂0 }}")
        
        XCTAssertEqual(train.scheduling, .stopped)
        XCTAssertEqual(train.state, .stopped)

        // Now let's reverse the train direction and pick the reverse route
        // TODO finish the test
//        p = try setup(layout: layout, fromBlockId: "s1", direction: .previous, route: layout.routes[1])
//        try p.assert("0: !{r0{s1 🛑🚂0 ≏ }} <t6,r> <t5> ![b3 ≏ ≏ ≏ ] <t4> ![b2 ≏ ] <t3> ![b1 ≏ ] <t2,s> <t1,l> !{r0{s1 🛑🚂0 ≏}}")
    }
    
    // MARK: -- Utility
    
    // Convenience structure to test the layout and its route
    private struct Package {
        let layout: Layout
        let train: Train
        let route: Route
        let asserter: LayoutAsserter
        let layoutController: LayoutController
        
        func assert(_ routeString: String) throws {
            try asserter.assert([routeString], route:route, trains: [train])
        }
    }
    
    private func setup(layout: Layout, fromBlockId: String, position: Position = .start, direction: Direction = .next, route: Route) throws -> Package {
        let train = layout.trains[0]
        try layout.setTrain(train.id, toBlock: Identifier<Block>(uuid: fromBlockId), position: position, direction: direction)
        XCTAssertEqual(train.speed.kph, 0)
                
        // Start the route
        let layoutController = LayoutController(layout: layout, interface: nil)
        try layoutController.start(routeID: route.id, trainID: train.id, destination: nil)

        XCTAssertEqual(train.scheduling, .running)

        let asserter = LayoutAsserter(layout: layout, layoutController: layoutController)
        
        return Package(layout: layout, train: train, route: route, asserter: asserter, layoutController: layoutController)
    }

}

private extension Layout {
    
    func newRoute(id: String, _ steps: [(String, Direction)]) -> Route {
        return newRoute(id, name: id, steps.map({ step in
            return Route.Step(Identifier<Block>(uuid: step.0), step.1)
        }))
    }
}
