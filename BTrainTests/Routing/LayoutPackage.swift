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

/// Helper class that the unit test uses to prepare, start and stop a train in a layout.
final class Package {
    enum Position {
        case start
        case end
        case automatic
        case custom(index: Int)
    }

    let digitalController = MockCommandInterface()
    let layout: Layout
    let asserter: LayoutAsserter
    let layoutController: LayoutController

    var trains = [Train]()
    var locomotives = [Locomotive]()
    var routes = [Route]()

    var train: Train {
        trains[0]
    }

    var loc: Locomotive {
        locomotives[0]
    }

    var route: Route {
        routes[0]
    }

    init(layout: Layout) {
        self.layout = layout
        layoutController = LayoutController(layout: layout, switchboard: nil, interface: digitalController, functionCatalog: nil)
        asserter = LayoutAsserter(layout: layout, layoutController: layoutController)

        layout.automaticRouteRandom = false
        layout.detectUnexpectedFeedback = true
    }

    func prepare(trainID: String, fromBlockId: String, position: Position = .start, direction: Direction = .next) throws {
        let routeId = Route.automaticRouteId(for: .init(uuid: trainID))
        try prepare(routeID: routeId.uuid, trainID: trainID, fromBlockId: fromBlockId, position: position, direction: direction)
    }

    func prepare(routeID: String, trainID: String, fromBlockId: String, position: Position = .start, direction: Direction = .next) throws {
        let train = layout.trains[Identifier<Train>(uuid: trainID)]!
        let route = layout.route(for: .init(uuid: routeID), trainId: .init(uuid: trainID))!
        let loc = train.locomotive!
        let block = layout.blocks[Identifier<Block>(uuid: fromBlockId)]!

        train.routeId = route.id
        switch position {
        case .start:
            let location = TrainPositions.head(blockId: block.id, index: 0, distance: 0.after, direction: direction)
            try setTrainInBlock(train: train, positions: location)
        case .end:
            let distance = block.feedbacks.last!.distance!
            let location = TrainPositions.head(blockId: block.id, index: block.feedbacks.count, distance: distance.after, direction: direction)
            try setTrainInBlock(train: train, positions: location)
        case let .custom(index):
            let distance = block.feedbacks[index - 1].distance!
            let location = TrainPositions.head(blockId: block.id, index: index, distance: direction == .next ? distance.after : distance.before, direction: direction)
            try setTrainInBlock(train: train, positions: location)
        case .automatic:
            try layoutController.setupTrainToBlock(train, block.id, naturalDirectionInBlock: direction)
        }

        XCTAssertEqual(loc.speed.requestedKph, 0)
        XCTAssertEqual(train.scheduling, .unmanaged)
        XCTAssertEqual(train.state, .stopped)

        try route.completePartialSteps(layout: layout, train: train)

        trains.append(train)
        locomotives.append(loc)
        routes.append(route)
    }

    func setTrainInBlock(train: Train, positions: TrainPositions) throws {
        try layout.setTrainPositions(train, positions)
    }

    func start(destination: Destination? = nil, expectedState: Train.State = .running, routeSteps: [String]? = nil) throws {
        try start(routeID: route.id.uuid, trainID: train.id.uuid, destination: destination, expectedState: expectedState, routeSteps: routeSteps)
    }

    func start(routeID: String, trainID: String, destination: Destination? = nil, expectedState: Train.State = .running, routeSteps: [String]? = nil) throws {
        try layoutController.start(routeID: Identifier<Route>(uuid: routeID), trainID: Identifier<Train>(uuid: trainID), destination: destination)
        let train = layout.trains[Identifier<Train>(uuid: trainID)]!
        XCTAssertEqual(train.scheduling, .managed)
        if let routeSteps = routeSteps {
            XCTAssertEqual(route.steps.toStrings(layout), routeSteps)
        }

        BTTestCase.wait(for: {
            train.state == expectedState
        }, timeout: 2.0)

        XCTAssertEqual(train.state, expectedState)
        XCTAssertEqual(train.scheduling, .managed)
    }

    func finish() {
        layoutController.finish(train: train)
    }

    func stop(drainAll: Bool = false) {
        layoutController.stop(train: train)
        if drainAll {
            layoutController.waitUntilSettled()
            XCTAssertEqual(train.scheduling, .unmanaged)
        }
    }

    func toggle(_ feedback: String, drainAll: Bool = true) {
        let f = layout.feedbacks[Identifier<Feedback>(uuid: feedback)]!
        f.detected.toggle()
        layoutController.runControllers(.feedbackTriggered(f))
        if drainAll {
            layoutController.waitUntilSettled()
        }
    }

    func toggle2(_ f1: String, _ f2: String) {
        toggle(f1)
        toggle(f2)
    }

    func assert(_ r1: String, _ leadingBlocks: [String]? = nil, expectRuntimeError: Bool = false) throws {
        // Drain all events when the interface is running. If the interface is on pause,
        // do not drain because the drain will never exits as the interface never executes.
        let drainAll = digitalController.running
        try asserter.assert([r1], trains: trains, resolver: layout, drainAll: drainAll, expectRuntimeError: expectRuntimeError)
        if let leadingBlocks = leadingBlocks {
            try assertLeadingBlocks(leadingBlocks)
        }
    }

    func assert2(_ r1: String, _ r2: String) throws {
        try asserter.assert([r1, r2], trains: trains, resolver: layout)
    }

    func assertLeadingBlocks(_ blockNames: [String]) throws {
        XCTAssertEqual(train.leading.blocks.toStrings(), blockNames)
    }

    func printASCII() throws {
        let producer = LayoutASCIIProducer(layout: layout)
        print(try producer.stringFrom(route: route, trainId: train.id, useBlockName: true, useTurnoutName: true))
    }
}

extension Layout: LayoutParserResolver {
    func blockId(forBlockName: String) -> BTrain.Identifier<BTrain.Block> {
        block(named: forBlockName).id
    }

    func turnoutId(forTurnoutName: String) -> BTrain.Identifier<BTrain.Turnout> {
        turnout(named: forTurnoutName).id
    }

    /// Returns the distance of the train in the specified block, given its direction of travel within the block and the feedback index.
    /// - Parameters:
    ///   - index: the feedback index that was triggered
    ///   - blockId: the block ID
    ///   - directionInBlock: the direction of travel of the train inside the block
    /// - Returns: the distance where the train is located
    func distance(forFeedbackAtPosition index: Int, blockId: BTrain.Identifier<BTrain.Block>, directionInBlock: Direction) -> Double {
        let block = blocks[blockId]!
        if index < 1 {
            if directionInBlock == .next {
                // Block:    [   f0    f1   ]>
                // Distance: |->
                // Train:  ---->
                return 0.after
            } else {
                // Block:    [    f0    f1   ]>
                // Distance: |-->
                // Train:        <------
                return block.feedbacks[index].distance!.before
            }
        } else {
            if directionInBlock == .next {
                // Block:    [   f0    f1   ]>
                // Distance: |----->
                // Train:  -------->
                return block.feedbacks[index - 1].distance!.after
            } else {
                // Block:    [    f0     f1   ]>
                // Distance: |--------->
                // Train:               <------
                if index < block.feedbacks.count {
                    return block.feedbacks[index].distance!.before
                } else {
                    return block.length!.before
                }
            }
        }
    }
}
