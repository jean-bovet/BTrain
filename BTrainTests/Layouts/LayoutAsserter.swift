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
    weak var layout: Layout!
    weak var layoutController: LayoutController!

    init(layout: Layout, layoutController: LayoutController) {
        self.layout = layout
        self.layoutController = layoutController
    }

    func assert(_ strings: [String], trains: [Train], resolver: LayoutParserResolver, drainAll: Bool = true, expectRuntimeError: Bool = false) throws {
        let expectedLayout = try LayoutFactory.layoutFrom(strings, resolver: resolver)
        let expectedTrains = Array(expectedLayout.trains)

        // First apply all the feedbacks
        var detectedFeedbacks = [Feedback]()
        for route in layout.routes {
            if let expectedRoute = expectedLayout.routes[route.id] {
                let feedbacks = applyFeedbacks(expectedSteps: expectedRoute.resolvedSteps, expectedLayout: expectedLayout)
                detectedFeedbacks.append(contentsOf: feedbacks)
            }
        }

        for feedback in detectedFeedbacks {
            layoutController.runControllers(.feedbackTriggered(feedback))
        }

        // Then run the controller to update the real layout states
        if drainAll {
            layoutController.waitUntilSettled()
        }

        // Ensure there is no generic runtime error
        if expectRuntimeError {
            XCTAssertNotNil(layout.runtimeError, "A layout runtime error is expected")
        } else {
            XCTAssertNil(layout.runtimeError, "The layout runtime encoutered an error")
        }

        // Now assert the routes to see if they match the real layout
        var assertedAtLeastOneRoute = false
        for route in layout.routes {
            // Expected route comes from the ASCII definition and is already a resolved route
            guard let expectedRoute = expectedLayout.routes[route.id] else {
                continue
            }

            // Only assert the routes that are specified in the expectation.
            // Some tests focus on a sub-set of the routes actually defined in the layout
            guard let train = trains.first(where: { $0.routeId == route.id }) else {
                continue
            }

            // Resolve the route
            let resolver = RouteResolver(layout: layout, train: train)
            let actualSteps = try resolver.resolve(unresolvedPath: route.steps, verbose: false).get().randomElement()!

            let producer = LayoutASCIIProducer(layout: layout)
            _ = try! producer.stringFrom(route: route, trainId: train.id)

            try assert(routeName: route.description, actualSteps: actualSteps, expectedSteps: expectedRoute.resolvedSteps,
                       trains: trains, expectedTrains: expectedTrains,
                       expectedLayout: expectedLayout)

            assertedAtLeastOneRoute = true
        }

        XCTAssertTrue(assertedAtLeastOneRoute, "At least one route should have been asserted!")
    }

    private func applyFeedbacks(expectedSteps: [ResolvedRouteItem], expectedLayout: LayoutParser.ParsedLayout) -> [Feedback] {
        var detectedFeedbacks = [Feedback]()
        for expectedStep in expectedSteps {
            switch expectedStep {
            case let .block(resolvedRouteItemBlock):
                let expectedBlock = resolvedRouteItemBlock.block
                for (index, expectedBlockFeedback) in expectedBlock.feedbacks.enumerated() {
                    let expectedFeedback = expectedLayout.feedbacks.first(where: { $0.id == expectedBlockFeedback.feedbackId })!
                    // The expectedFeedbackId is only valid for the expectedLayout because
                    // the ASCII representation does not allow to specify an ID for the feedback,
                    // which means they will have random UUID. It is best to use the index
                    // of the feedback within the block instead.
                    let block = layout.blocks[expectedBlock.id] ?? layout.block(named: expectedBlock.id.uuid)
                    let blockFeedback = block.feedbacks[index]
                    let feedback = layout.feedbacks[blockFeedback.feedbackId]!
                    feedback.detected = expectedFeedback.detected
                    if feedback.detected {
                        detectedFeedbacks.append(feedback)
                    }
                }

            case .turnout:
                break
            }
        }
        return detectedFeedbacks
    }

    private func assert(routeName: String, actualSteps: [ResolvedRouteItem], expectedSteps: [ResolvedRouteItem], trains _: [Train], expectedTrains: [Train], expectedLayout: LayoutParser.ParsedLayout) throws {
        for (index, expectedTrain) in expectedTrains.enumerated() {
            let train = layout.trains[expectedTrain.id]!
            XCTAssertEqual(train.id, expectedTrain.id, "Unexpected train mismatch at index \(index), route \(routeName)")

            if train.directionForward {
                XCTAssertEqual(train.position.front, expectedTrain.position.front, "Mismatching train front position for train \(expectedTrain.id), route \(routeName)")
                // Note: the back position distance cannot be asserted accurately because the ASCII representation does not allow (yet) to specify the distance between feedback,
                // which is usually where the position ends up after the algorithm computes the exact location from the front position and the length of the train.
                if let back = train.position.back {
                    // Note: if the back position is not specified, it means it ended up in a turnout which is not yet handled (so nil is assigned to the position)
                    XCTAssertEqual(back.blockId, expectedTrain.position.back?.blockId, "Mismatching train back position blockId for train \(expectedTrain.id), route \(routeName)")
                    XCTAssertEqual(back.index, expectedTrain.position.back?.index, "Mismatching train back position index for train \(expectedTrain.id), route \(routeName)")
                }
            } else {
                XCTAssertEqual(train.position.back, expectedTrain.position.back, "Mismatching train back position for train \(expectedTrain.id), route \(routeName)")
                // Note: the front position distance cannot be asserted accurately because the ASCII representation does not allow (yet) to specify the distance between feedback,
                // which is usually where the position ends up after the algorithm computes the exact location from the front position and the length of the train.
                XCTAssertEqual(train.position.front?.index, expectedTrain.position.front?.index, "Mismatching train front position index for train \(expectedTrain.id), route \(routeName)")
            }
            XCTAssertEqual(train.speed!.requestedKph, expectedTrain.speed!.requestedKph, accuracy: 1, "Mismatching train speed for train \(expectedTrain.id), route \(routeName)")
        }

        guard actualSteps.count == expectedSteps.count else {
            XCTFail("Mismatching number of steps for route \(routeName): expecting \(expectedSteps.count) but got \(actualSteps.count)")
            return
        }

        var previousStep: ResolvedRouteItem?
        for index in 0 ..< actualSteps.count {
            let step = actualSteps[index]
            let expectedStep = expectedSteps[index]

            switch step {
            case let .block(stepBlock):
                guard case let .block(expectedStepBlock) = expectedStep else {
                    XCTFail("Expected step should be a block \(expectedStep)")
                    return
                }
                XCTAssertEqual(stepBlock.blockId, expectedStepBlock.blockId, "Step blockId mismatch at index \(index)")
                XCTAssertEqual(step.entrySocket, expectedStep.entrySocket, "Step entrySocket mismatch at block \(stepBlock.blockId)")
                XCTAssertEqual(step.exitSocket, expectedStep.exitSocket, "Step exitSocket mismatch at block \(stepBlock.blockId)")
                assertBlockAt(index: index, routeName: routeName, step: stepBlock, expectedStep: expectedStepBlock, expectedLayout: expectedLayout)
            case let .turnout(stepTurnout):
                guard case let .turnout(expectedStepTurnout) = expectedStep else {
                    XCTFail("Expected step should be a turnout \(expectedStep)")
                    return
                }
                XCTAssertEqual(stepTurnout.turnout.id, expectedStepTurnout.turnout.id, "Step turnoutId mismatch at index \(index)")
                XCTAssertEqual(step.entrySocket, expectedStep.entrySocket, "Step entrySocket mismatch at turnout \(stepTurnout.turnout.id)")
                XCTAssertEqual(step.exitSocket, expectedStep.exitSocket, "Step exitSocket mismatch at turnout \(stepTurnout.turnout.id)")
                assertTurnoutAt(index: index, routeName: routeName, step: stepTurnout, expectedStep: expectedStepTurnout, expectedLayout: expectedLayout)
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
            // by ensuring the transition (out of or into) a turnout matches the sockets reachable by the state of the turnout.
            if let previousStep = previousStep {
                var reserved: Identifier<Train>?
                var fromElementName: String
                var toElementName: String
                switch previousStep {
                case let .block(resolvedRouteItemBlock):
                    reserved = resolvedRouteItemBlock.block.reservation?.trainId
                    fromElementName = resolvedRouteItemBlock.block.name

                case let .turnout(resolvedRouteItemTurnout):
                    reserved = resolvedRouteItemTurnout.turnout.reserved?.train
                    fromElementName = resolvedRouteItemTurnout.turnout.name
                    // Check that the actual exitSocket is one that the state of the turnout allows, otherwise
                    // this means that this transition is not going to be used for the reservation and can be skipped.
                    if resolvedRouteItemTurnout.turnout.socketId(fromSocketId: resolvedRouteItemTurnout.exitSocketId, withState: resolvedRouteItemTurnout.turnout.actualState) == nil {
                        reserved = nil
                    }
                }

                switch step {
                case let .block(resolvedRouteItemBlock):
                    toElementName = resolvedRouteItemBlock.block.name
                    if reserved != resolvedRouteItemBlock.block.reservation?.trainId {
                        reserved = nil
                    }
                case let .turnout(resolvedRouteItemTurnout):
                    let turnout = resolvedRouteItemTurnout.turnout
                    toElementName = turnout.name
                    if reserved != turnout.reserved?.train {
                        reserved = nil
                    } else {
                        // Check that the actual entrySocket is one that the state of the turnout allows, otherwise
                        // this means that this transition is not going to be used for the reservation and can be skipped.
                        if turnout.socketId(fromSocketId: resolvedRouteItemTurnout.entrySocketId, withState: turnout.actualState) == nil {
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

    private func assertBlockAt(index: Int, routeName: String, step: ResolvedRouteItemBlock, expectedStep: ResolvedRouteItemBlock, expectedLayout: LayoutParser.ParsedLayout) {
        XCTAssertEqual(step.direction, expectedStep.direction, "Step direction mismatch at index \(index)")

        let block = layout.blocks[step.blockId]!
        let expectedBlock = expectedLayout.blocks.first(where: { $0.id == expectedStep.blockId })!
        XCTAssertEqual(block.category, expectedBlock.category, "Block category mismatch for block \(block)")

        if expectedBlock.reservation == nil {
            XCTAssertNil(block.reservation, "Expected no reservation in block \(block), route \(routeName)")
        } else {
            // Note: we only care about the trainId, not the direction of travel
            // because the same block in the ASCII representation can indicate
            // a different travel direction (because it represents the block
            // in a later phase of the route).
            XCTAssertEqual(block.reservation?.trainId, expectedBlock.reservation?.trainId, "Mismatching reserved block \(block) at index \(index), route \(routeName)")
        }

        if let expectedTrain = expectedBlock.trainInstance {
            XCTAssertEqual(block.trainInstance?.trainId, expectedTrain.trainId, "Unexpected train mismatch in block \(block.name) at index \(index)")
        } else {
            XCTAssertNil(block.trainInstance, "Block \(block) should not contain train \(block.trainInstance!)")
        }

        // Assert the parts of the block reserved for the train and its wagon
        // TODO: finish to remove the parts
//        if let train = block.trainInstance, let expectedTrain = expectedBlock.trainInstance {
//            XCTAssertEqual(train.parts, expectedTrain.parts, "Unexpected train parts mismatch in block \(block) at index \(index), route \(routeName)")
//        }
    }

    private func assertTurnoutAt(index: Int, routeName: String, step: ResolvedRouteItemTurnout, expectedStep: ResolvedRouteItemTurnout, expectedLayout _: LayoutParser.ParsedLayout) {
        let turnout = step.turnout
        let expectedTurnout = expectedStep.turnout
        XCTAssertEqual(turnout.id, expectedTurnout.id, "Mismatching turnout ID at index \(index), route \(routeName)")
        XCTAssertEqual(turnout.actualState, expectedTurnout.actualState, "Mismatching turnout state for \(turnout) at index \(index), route \(routeName)")
        XCTAssertEqual(turnout.reserved?.train, expectedTurnout.reserved?.train, "Mismatching turnout reservation for \(turnout) at index \(index), route \(routeName)")
    }
}
