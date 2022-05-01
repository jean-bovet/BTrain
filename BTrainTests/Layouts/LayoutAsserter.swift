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

import Foundation
import XCTest

@testable import BTrain

final class LayoutAsserter {
    
    let layout: Layout
    let layoutController: LayoutController
    
    var assertBlockParts = false
    
    init(layout: Layout, layoutController: LayoutController) {
        self.layout = layout
        self.layoutController = layoutController
    }
    
    func assert(_ strings: [String], trains: [Train]) throws {
        let expectedLayout = try LayoutFactory.layoutFrom(strings)
        let expectedTrains = expectedLayout.trains
        
        // First apply all the feedbacks
        for route in layout.routes {
            if let expectedRoute = expectedLayout.routes.first(where: { $0.id == route.id }) {
                applyFeedbacks(route: route, expectedRoute: expectedRoute, expectedLayout: expectedLayout)
            }
        }
        
        // Then run the controller to update the real layout states
        layoutController.runControllers(.feedbackTriggered)

        // Now assert the routes to see if they match the real layout
        var assertedAtLeastOneRoute = false
        for route in layout.routes {
            // Expected route comes from the ASCII definition and is already a resolved route
            guard let expectedRoute = expectedLayout.routes.first(where: { $0.id == route.id }) else {
                continue
            }
            
            // Only assert the routes that are specified in the expectation.
            // Some tests focus on a sub-set of the routes actually defined in the layout
            guard let train = trains.first(where: { $0.routeId == route.id }) else {
                continue
            }
            
            // Resolve the route
            if try route.resolve(layout: layout, train: train) == false {
                continue
            }
            
            let producer = LayoutASCIIProducer(layout: layout)
            let routeString = try! producer.stringFrom(route: route, trainId: train.id)
            print(routeString)
            
            try assert(route: route, expectedRoute: expectedRoute,
                       trains: trains, expectedTrains: expectedTrains,
                       expectedLayout: expectedLayout)

            assertedAtLeastOneRoute = true
        }
        
        XCTAssertTrue(assertedAtLeastOneRoute, "At least one route should have been asserted!")
    }
    
    private func applyFeedbacks(route: Route, expectedRoute: Route, expectedLayout: Layout) {
        for expectedStep in expectedRoute.resolvedSteps {
            switch expectedStep {
            case .block(let resolvedRouteItemBlock):
                let expectedBlock = resolvedRouteItemBlock.block
                for (index, expectedBlockFeedback) in expectedBlock.feedbacks.enumerated() {
                    let expectedFeedback = expectedLayout.feedback(for: expectedBlockFeedback.feedbackId)!
                    // The expectedFeedbackId is only valid for the expectedLayout because
                    // the ASCII representation does not allow to specify an ID for the feedback,
                    // which means they will have random UUID. It is best to use the index
                    // of the feedback within the block instead.
                    let block = layout.block(for: expectedBlock.id) ?? layout.block(named: expectedBlock.id.uuid)
                    let blockFeedback = block.feedbacks[index]
                    let feedback = layout.feedback(for: blockFeedback.feedbackId)!
                    feedback.detected = expectedFeedback.detected
                }

            case .turnout(_):
                break
            }
        }
    }
    
    private func assert(route: Route, expectedRoute: Route, trains: [Train], expectedTrains: [Train], expectedLayout: Layout) throws {
        for (index, expectedTrain) in expectedTrains.enumerated() {
            let train = layout.train(for: expectedTrain.id)!
            XCTAssertEqual(train.id, expectedTrain.id, "Unexpected train mismatch at index \(index), route \(route.id)")
            XCTAssertEqual(train.position, expectedTrain.position, "Mismatching train position for train \(expectedTrain.id), route \(route.id)")
            XCTAssertEqual(train.speed.requestedKph, expectedTrain.speed.requestedKph, accuracy: 1, "Mismatching train speed for train \(expectedTrain.id), route \(route.id)")
        }
                
        guard route.resolvedSteps.count == expectedRoute.resolvedSteps.count else {
            XCTFail("Mismatching number of steps for route \(route): expecting \(expectedRoute.resolvedSteps.count) but got \(route.resolvedSteps.count)")
            return
        }
        
        var previousStep: ResolvedRouteItem?
        for index in 0..<route.resolvedSteps.count {
            let step = route.resolvedSteps[index]
            let expectedStep = expectedRoute.resolvedSteps[index]
            
            switch step {
            case .block(let stepBlock):
                guard case .block(let expectedStepBlock) = expectedStep else {
                    XCTFail("Expected step should be a block \(expectedStep)")
                    return
                }
                XCTAssertEqual(namedId(stepBlock.blockId), expectedStepBlock.blockId, "Step blockId mismatch at index \(index)")
                XCTAssertEqual(namedId(step.entrySocket), expectedStep.entrySocket, "Step entrySocket mismatch at block \(stepBlock.blockId)")
                XCTAssertEqual(namedId(step.exitSocket), expectedStep.exitSocket, "Step exitSocket mismatch at block \(stepBlock.blockId)")
                assertBlockAt(index: index, route: route, step: stepBlock, expectedStep: expectedStepBlock, expectedLayout: expectedLayout)
            case .turnout(let stepTurnout):
                guard case .turnout(let expectedStepTurnout) = expectedStep else {
                    XCTFail("Expected step should be a turnout \(expectedStep)")
                    return
                }
                XCTAssertEqual(namedId(stepTurnout.turnout.id), expectedStepTurnout.turnout.id, "Step turnoutId mismatch at index \(index)")
                XCTAssertEqual(namedId(step.entrySocket), expectedStep.entrySocket, "Step entrySocket mismatch at turnout \(stepTurnout.turnout.id)")
                XCTAssertEqual(namedId(step.exitSocket), expectedStep.exitSocket, "Step exitSocket mismatch at turnout \(stepTurnout.turnout.id)")
                assertTurnoutAt(index: index, route: route, step: stepTurnout, expectedStep: expectedStepTurnout, expectedLayout: expectedLayout)
            }
            
            // Check that the transitions between two elements that are reserved are also reserved
            // Take extra care to not assert a transition between two blocks that are reserved
            // for the same train but that are not actually linked - see diagram:
            //                     ┏━━━━━━━━━┓
            //    ┏━━━━━━━━━━━━━━━━┃ Block 2 ┃◀━━━━━━━━━━━━━━━━━━━━┓
            //    ┃                ┗━━━━━━━━━┛                     ┃
            //    ┃                                                ┃
            //    ┃                                                ●
            //    ┃                ┏━━━━━━━━━┓                 ┏━━━━━━━┓
            //    ┃       ┏━━━━━━━▶┃ Block 3 ┃─ ─ ─ ─ ─ ─ ─ ─ ▶┃Turnout┃
            //    ┃       ┃        ┗━━━━━━━━━┛                 ┗━━━━━━━┛
            //    ┃       ┃                                        ▲
            //    ┃       ●                                        ┃
            //    ┃  ┏━━━━━━━━┓                     ┏━━━━━━━━━┓    ┃
            //    ┗━▶┃Turnout2┃─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ▶┃ Block 1 ┃━━━━┛
            //       ┗━━━━━━━━┛                     ┗━━━━━━━━━┛
            // The transition between Block 3 and Turnout is not reserved because the locomotive is in Block 3
            // and the wagons of the train are occupying all the tracks until Block 1. We can determine this
            // by ensuring the transition (out of or into) a turnout matches the sockets reacheable by the state of the turnout.
            if let previousStep = previousStep {
                var reserved: Identifier<Train>?
                var fromElementName: String
                var toElementName: String
                switch previousStep {
                case .block(let resolvedRouteItemBlock):
                    reserved = resolvedRouteItemBlock.block.reserved?.trainId
                    fromElementName = resolvedRouteItemBlock.block.name

                case .turnout(let resolvedRouteItemTurnout):
                    reserved = resolvedRouteItemTurnout.turnout.reserved?.train
                    fromElementName = resolvedRouteItemTurnout.turnout.name
                    // Check that the actual exitSocket is one that the state of the turnout allows, otherwise
                    // this means that this transition is not going to be used for the reservation and can be skipped.
                    if resolvedRouteItemTurnout.turnout.socketId(fromSocketId: resolvedRouteItemTurnout.exitSocketId, withState: resolvedRouteItemTurnout.turnout.state) == nil {
                        reserved = nil
                    }

                }
                
                switch step {
                case .block(let resolvedRouteItemBlock):
                    toElementName = resolvedRouteItemBlock.block.name
                    if reserved != resolvedRouteItemBlock.block.reserved?.trainId {
                        reserved = nil
                    }
                case .turnout(let resolvedRouteItemTurnout):
                    let turnout = resolvedRouteItemTurnout.turnout
                    toElementName = turnout.name
                    if reserved != turnout.reserved?.train {
                        reserved = nil
                    } else {
                        // Check that the actual entrySocket is one that the state of the turnout allows, otherwise
                        // this means that this transition is not going to be used for the reservation and can be skipped.
                        if turnout.socketId(fromSocketId: resolvedRouteItemTurnout.entrySocketId, withState: turnout.state) == nil {
                            reserved = nil
                        }
                    }
                }

                let exitSocket = previousStep.exitSocket
                let entrySocket = step.entrySocket
                if reserved != nil {
                    let transitions = try layout.transitions(from: exitSocket, to: entrySocket)
                    XCTAssertFalse(transitions.isEmpty)
                    for transition in transitions {
                        XCTAssertNotNil(transition.reserved, "Transition should be reserved between \(fromElementName) and \(toElementName)")
                        XCTAssertEqual(reserved, transition.reserved, "Transition should have a reservation between \(fromElementName) and \(toElementName)")
                    }
                }

            }
            
            previousStep = step
        }
    }
    
    private func assertBlockAt(index: Int, route: Route, step: ResolvedRouteItemBlock, expectedStep: ResolvedRouteItemBlock, expectedLayout: Layout) {
        XCTAssertEqual(step.direction, expectedStep.direction, "Step direction mismatch at index \(index)")

        let block = layout.block(for: step.blockId)!
        let expectedBlock = expectedLayout.block(for: expectedStep.blockId)!
        XCTAssertEqual(block.category, expectedBlock.category, "Block category mismatch for block \(block)")

        if expectedBlock.reserved == nil {
            XCTAssertNil(block.reserved, "Expected no reservation in block \(block), route \(route)")
        } else {
            // Note: we only care about the trainId, not the direction of travel
            // because the same block in the ASCII representation can indicate
            // a different travel direction (because it represents the block
            // in a later phase of the route).
            XCTAssertEqual(block.reserved?.trainId, expectedBlock.reserved?.trainId, "Mismatching reserved block \(block) at index \(index), route \(route)")
        }
        
        if let expectedTrain = expectedBlock.train {
            XCTAssertEqual(block.train?.trainId, expectedTrain.trainId, "Unexpected train mismatch in block \(block.name) at index \(index)")
        } else {
            XCTAssertNil(block.train, "Block \(block) should not contain train \(block.train!)")
        }
        
        // Assert the parts of the block reserved for the train and its wagon
        if let train = block.train, let expectedTrain = expectedBlock.train, assertBlockParts {
            XCTAssertEqual(train.parts, expectedTrain.parts, "Unexpected train parts mismatch in block \(block) at index \(index), route \(route)")
        }
    }
    
    private func assertTurnoutAt(index: Int, route: Route, step: ResolvedRouteItemTurnout, expectedStep: ResolvedRouteItemTurnout, expectedLayout: Layout) {
        let turnout = step.turnout
        let expectedTurnout = expectedStep.turnout
        XCTAssertEqual(namedId(turnout.id), expectedTurnout.id, "Mismatching turnout ID at index \(index), route \(route)")
        XCTAssertEqual(turnout.state, expectedTurnout.state, "Mismatching turnout state for \(turnout) at index \(index), route \(route)")
        XCTAssertEqual(turnout.reserved?.train, expectedTurnout.reserved?.train, "Mismatching turnout reservation for \(turnout) at index \(index), route \(route)")
    }
}

// This extension converts an identifier to another one that uses the name of the element as the uuid.
// Note: this is because in the unit tests, the assertion is done using the easier to remember name instead of uuid.
extension LayoutAsserter {
    
    private func namedId(_ blockId: Identifier<Block>?) -> Identifier<Block>? {
        if let block = layout.block(for: blockId) {
            return .init(uuid: block.name)
        } else {
            return blockId
        }
    }

    private func namedId(_ turnoutId: Identifier<Turnout>?) -> Identifier<Turnout>? {
        if let turnout = layout.turnout(for: turnoutId) {
            return .init(uuid: turnout.name)
        } else {
            return turnoutId
        }
    }

    private func namedId(_ socket: Socket?) -> Socket? {
        guard let socket = socket else {
            return nil
        }

        return .init(block: namedId(socket.block), turnout: namedId(socket.turnout), socketId: socket.socketId)
    }

}
