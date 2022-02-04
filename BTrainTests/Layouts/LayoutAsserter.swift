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
    
    func assert(_ strings: [String], route: Route, trains: [Train]) throws {
        let expectedLayout = LayoutFactory.layoutFrom(strings)
        let expectedTrains = expectedLayout.trains
        
        // First apply all the feedbacks
        for route in layout.routes {
            if let expectedRoute = expectedLayout.routes.first(where: { $0.id == route.id }) {
                applyFeedbacks(route: route, expectedRoute: expectedRoute, expectedLayout: expectedLayout)
            }
        }
        
        // Then run the controller to update the real layout states
        _ = layoutController.run()

        // Now assert the routes to see if they match the real layout
        var assertedAtLeastOneRoute = false
        for route in layout.routes {
            if let expectedRoute = expectedLayout.routes.first(where: { $0.id == route.id }) {
                // Only assert the routes that are specified in the expectation.
                // Some tests focus on a sub-set of the routes actually defined in the layout
                try assert(route: route, expectedRoute: expectedRoute,
                           trains: trains, expectedTrains: expectedTrains,
                           expectedLayout: expectedLayout)
                
                assertedAtLeastOneRoute = true
            }
        }
        
        XCTAssertTrue(assertedAtLeastOneRoute, "At least one route should have been asserted!")
    }
    
    private func applyFeedbacks(route: Route, expectedRoute: Route, expectedLayout: Layout) {
        for expectedStep in expectedRoute.steps {
            let expectedBlock = expectedLayout.block(for: expectedStep.blockId)!
            let block = layout.block(for: expectedStep.blockId)
            for (index, expectedBlockFeedback) in expectedBlock.feedbacks.enumerated() {
                let expectedFeedback = expectedLayout.feedback(for: expectedBlockFeedback.feedbackId)!
                // The expectedFeedbackId is only valid for the expectedLayout because
                // the ASCII representation does not allow to specify an ID for the feedback,
                // which means they will have random UUID. It is best to use the index
                // of the feedback within the block instead.
                let blockFeedback = block?.feedbacks[index]
                let feedback = layout.feedback(for: blockFeedback?.feedbackId)!
                feedback.detected = expectedFeedback.detected
            }
        }
    }
    
    private func assert(route: Route, expectedRoute: Route, trains: [Train], expectedTrains: [Train], expectedLayout: Layout) throws {

        for (index, expectedTrain) in expectedTrains.enumerated() {
            let train = layout.train(for: expectedTrain.id)!
            XCTAssertEqual(train.id, expectedTrain.id, "Unexpected train mismatch at index \(index), route \(route.id)")
            XCTAssertEqual(train.position, expectedTrain.position, "Mismatching train position for train \(expectedTrain.id), route \(route.id)")
            XCTAssertEqual(train.speed, expectedTrain.speed, "Mismatching train speed for train \(expectedTrain.id), route \(route.id)")
        }
        
        XCTAssertEqual(route.steps.count, expectedRoute.steps.count, "Mismatching number of steps for route \(route)")
        for index in 0..<route.steps.count {
            let step = route.steps[index]
            let expectedStep = expectedRoute.steps[index]
            
            XCTAssertEqual(step.blockId, expectedStep.blockId, "Step blockId mismatch at index \(index)")
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
                XCTAssertEqual(block.train?.trainId, expectedTrain.trainId, "Unexpected train mismatch in block at index \(index)")
            } else {
                XCTAssertNil(block.train, "Block \(block) should not contain train \(block.train!)")
            }
            
            // Assert the parts of the block reserved for the train and its wagon
            if let train = block.train, let expectedTrain = expectedBlock.train, assertBlockParts {
                XCTAssertEqual(train.parts, expectedTrain.parts, "Unexpected train parts mismatch in block \(block) at index \(index), route \(route)")
            }
            
            // In ASCII representation, there is only one next transition from one block to another, for example:
            // [b1 ≏ ≏ ] [b2 ≏ ≏ ] which represents a single transition going from b1 to b2 without turnout
            // [b1 ≏ ≏ ] - [b2 ≏ ≏ ] which represents a single turnout for a single transition going from b1 to b2
            // [b1 ≏ ≏ ] -- [b2 ≏ ≏ ] which represents two turnouts for a single transition going from b1 to b2
            if index < route.steps.count - 1 {
                let nextExpectedStep = route.steps[index+1]
                let nextExpectedBlock = layout.block(for: nextExpectedStep.blockId)!

                let expectedTransitions = try expectedLayout.transitions(from: expectedBlock, to: nextExpectedBlock, direction: expectedStep.direction!)
                XCTAssertFalse(expectedTransitions.isEmpty, "Expecting at least 1 transition between \(expectedBlock) and \(nextExpectedBlock)")
                
                let transitions = try layout.transitions(from: expectedBlock, to: nextExpectedBlock, direction: step.direction!)
                XCTAssertEqual(transitions.count, expectedTransitions.count, "Mismatching number of transitions between \(expectedBlock) and \(nextExpectedBlock)")
                
                let expectedTurnouts = try expectedLayout.turnouts(from: expectedBlock, to: nextExpectedBlock, direction: expectedStep.direction!)
                let turnouts = try layout.turnouts(from: expectedBlock, to: nextExpectedBlock, direction: step.direction!)
                XCTAssertEqual(turnouts.count, expectedTurnouts.count, "Mismatching number of turnouts between \(expectedBlock) and \(nextExpectedBlock)")

                for index in 0..<turnouts.count {
                    let turnout = turnouts[index]
                    let expectedTurnout = expectedTurnouts[index]
                    
                    XCTAssertEqual(turnout.id, expectedTurnout.id, "Mismatching turnout IDs in block \(block), route \(route)")
                    XCTAssertEqual(turnout.state, expectedTurnout.state, "Unexpected turnout \(turnout.id) state in block \(block), route \(route)")
                    XCTAssertEqual(turnout.reserved, expectedTurnout.reserved, "Turnout \(turnout.id) has a mismatching reservation in block \(block), route \(route)")
                }
            }
        }
    }
}
