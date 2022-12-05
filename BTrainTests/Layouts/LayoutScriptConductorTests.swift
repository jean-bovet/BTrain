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

@testable import BTrain
import XCTest

final class LayoutScriptConductorTests: XCTestCase {
    func testScheduleEmptyScript() throws {
        let layout = Layout()
        let conductor = LayoutScriptConductor(layout: layout)

        let controller = MockLayoutController(layout: layout)
        conductor.layoutControlling = controller

        XCTAssertEqual(controller.startedCount, 0)

        let script = LayoutScript(name: "Test")
        layout.layoutScripts.add(script)
        conductor.schedule(script.id)

        XCTAssertEqual(controller.startedCount, 0)

        try conductor.tick()

        XCTAssertEqual(controller.startedCount, 0)
    }

    func testScheduleScriptWithInvalidCommand() throws {
        let layout = Layout()
        let conductor = LayoutScriptConductor(layout: layout)

        let controller = MockLayoutController(layout: layout)
        conductor.layoutControlling = controller

        XCTAssertEqual(controller.startedCount, 0)

        let script = LayoutScript(name: "Test")
        script.commands.append(LayoutScriptCommand(action: .run))
        layout.layoutScripts.add(script)
        conductor.schedule(script.id)

        XCTAssertEqual(controller.startedCount, 0)

        XCTAssertThrowsError(try conductor.tick())
    }

    func testScriptWithSingleCommand() throws {
        let layout = LayoutLoop1().newLayout()
        let conductor = LayoutScriptConductor(layout: layout)

        let controller = MockLayoutController(layout: layout)
        conductor.layoutControlling = controller

        XCTAssertEqual(controller.startedCount, 0)
        XCTAssertTrue(layout.layoutScripts.elements.isEmpty)

        // Note: RouteScripts have the same UUID as their Route counterpart so they can update the Route whenever they are updated.
        let routeScript = simpleRouteScript(withUUID: layout.routes[0].id.uuid)
        layout.routeScripts.add(routeScript)

        let layoutScript = layoutScriptWithSingleCommand(train: layout.trains[0].id, routeScript: layout.routeScripts[0].id)
        layout.layoutScripts.add(layoutScript)

        // Schedule to start and will stop by indicating that the train has finished the route
        // for the script command.
        conductor.schedule(layoutScript.id)
        XCTAssertEqual(controller.startedCount, 0)

        try conductor.tick()
        XCTAssertEqual(controller.startedCount, 1)

        try conductor.tick()
        XCTAssertEqual(controller.startedCount, 1)

        layout.trains[0].scheduling = .unmanaged
        try conductor.tick()
        XCTAssertEqual(controller.startedCount, 1)
        XCTAssertNil(conductor.currentScript)

        // Schedule to start again and will stop explicitly the script instead of waiting
        // for the train to finish the route
        conductor.schedule(layoutScript.id)

        try conductor.tick()
        XCTAssertEqual(controller.startedCount, 2)

        // Cannot stop a script that is not currently running
        XCTAssertThrowsError(try conductor.stop(.init(uuid: "foo")))

        try conductor.stop(layoutScript.id)
        try conductor.tick()
        XCTAssertEqual(controller.startedCount, 2)
        XCTAssertNil(conductor.currentScript)
    }

    func testScriptWithChildren() throws {
        let layout = LayoutLoop1().newLayout()
        let conductor = LayoutScriptConductor(layout: layout)

        let controller = MockLayoutController(layout: layout)
        conductor.layoutControlling = controller

        XCTAssertEqual(controller.startedCount, 0)
        XCTAssertTrue(layout.layoutScripts.elements.isEmpty)

        // Note: RouteScripts have the same UUID as their Route counterpart so they can update the Route whenever they are updated.
        let routeScript = simpleRouteScript(withUUID: layout.routes[0].id.uuid)
        layout.routeScripts.add(routeScript)

        let layoutScript = layoutScriptWithChildCommand(train: layout.trains[0].id, routeScript: layout.routeScripts[0].id)
        layout.layoutScripts.add(layoutScript)

        // Schedule to start and will stop by indicating that the train has finished the route
        // for the script command.
        conductor.schedule(layoutScript.id)
        XCTAssertEqual(controller.startedCount, 0)

        try conductor.tick()
        XCTAssertEqual(controller.startedCount, 1)

        try conductor.tick()
        XCTAssertEqual(controller.startedCount, 1)

        layout.trains[0].scheduling = .unmanaged

        // Now the child command will start executing
        try conductor.tick()
        XCTAssertEqual(controller.startedCount, 2)
        XCTAssertNotNil(conductor.currentScript)

        layout.trains[0].scheduling = .unmanaged

        try conductor.tick()
        XCTAssertEqual(controller.startedCount, 2)
        XCTAssertNil(conductor.currentScript)
    }

    func testScriptWithIdenticalCommands() throws {
        let layout = LayoutLoop1().newLayout()
        let conductor = LayoutScriptConductor(layout: layout)

        let controller = LayoutController(layout: layout, switchboard: nil, interface: MockCommandInterface())
        conductor.layoutControlling = controller

        XCTAssertTrue(layout.layoutScripts.elements.isEmpty)

        let route = layout.routes[0]
        let train = layout.trains[0]
        try controller.setupTrainToBlock(train, route.partialSteps[0].stepBlockId!, naturalDirectionInBlock: .next)

        // Note: RouteScripts have the same UUID as their Route counterpart so they can update the Route whenever they are updated.
        let routeScript = simpleRouteScript(withUUID: route.id.uuid)
        layout.routeScripts.add(routeScript)

        let layoutScript = layoutScriptTwoSiblingIdenticalCommand(train: train.id, routeScript: layout.routeScripts[0].id)
        layout.layoutScripts.add(layoutScript)

        // Schedule to start the script which will schedule for execution all the commands at the same level.
        // Because the two commands use the same train, the second command will have to wait for the first train
        // to finish before start - otherwise there will be an exception because one train cannot be started
        // more than once!
        conductor.schedule(layoutScript.id)
        XCTAssertNotNil(conductor.currentScript)

        try conductor.tick()
        try conductor.tick()

        // Indicate that the train has stopped
        train.scheduling = .unmanaged

        // Now the second command will start executing
        try conductor.tick()
        XCTAssertNotNil(conductor.currentScript)

        train.scheduling = .unmanaged

        try conductor.tick()
        XCTAssertNil(conductor.currentScript)
    }

    private func simpleRouteScript(withUUID uuid: String) -> RouteScript {
        let script = RouteScript(uuid: uuid)
        let command = RouteScriptCommand(action: .start)
        script.commands.append(command)
        return script
    }

    private func layoutScriptWithSingleCommand(train: Identifier<Train>, routeScript: Identifier<RouteScript>) -> LayoutScript {
        let script = LayoutScript(name: "Test")
        var command = LayoutScriptCommand(action: .run)
        command.trainId = train
        command.routeScriptId = routeScript
        script.commands.append(command)
        return script
    }

    private func layoutScriptWithChildCommand(train: Identifier<Train>, routeScript: Identifier<RouteScript>) -> LayoutScript {
        let script = LayoutScript(name: "Test")
        var command = LayoutScriptCommand(action: .run)
        command.trainId = train
        command.routeScriptId = routeScript

        var child = LayoutScriptCommand(action: .run)
        child.trainId = train
        child.routeScriptId = routeScript
        command.children.append(child)

        script.commands.append(command)
        return script
    }

    private func layoutScriptTwoSiblingIdenticalCommand(train: Identifier<Train>, routeScript: Identifier<RouteScript>) -> LayoutScript {
        let script = LayoutScript(name: "Test")

        var command = LayoutScriptCommand(action: .run)
        command.trainId = train
        command.routeScriptId = routeScript
        script.commands.append(command)

        var command2 = LayoutScriptCommand(action: .run)
        command2.trainId = train
        command2.routeScriptId = routeScript
        script.commands.append(command2)

        return script
    }

    final class MockLayoutController: LayoutControlling {
        let layout: Layout
        var startedCount = 0

        internal init(layout: Layout, startedCount: Int = 0) {
            self.layout = layout
            self.startedCount = startedCount
        }

        func start(routeID _: BTrain.Identifier<BTrain.Route>, trainID: BTrain.Identifier<BTrain.Train>) throws {
            startedCount += 1
            layout.trains[trainID]!.scheduling = .managed
        }

        func stop(train _: BTrain.Train) {}
    }
}
