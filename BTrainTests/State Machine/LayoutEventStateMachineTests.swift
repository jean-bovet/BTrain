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

class LayoutEventStateMachineTests: XCTestCase {
    var train: MockTrainController!
    let lsm = LayoutEventStateMachine()

    override func setUp() {
        super.setUp()
        train = MockTrainController(route: Route(uuid: "fixed-test", mode: .fixed))
    }

    func testLayoutEventFeedback() throws {
        let f1 = Feedback("f1")

        train.onUpdatePosition = { f in f == f1 }
        XCTAssertEqual(try lsm.handle(layoutEvent: .feedback(f1), train: train), nil)

        train.mode = .managed

        train.onUpdatePosition = { f in f == f1 }
        XCTAssertEqual(try lsm.handle(layoutEvent: .feedback(f1), train: train), nil)

        train.state = .running

        train.onUpdatePosition = { f in f == f1 }
        XCTAssertEqual(try lsm.handle(layoutEvent: .feedback(f1), train: train), .position(train))

        train.onUpdatePosition = { _ in false }
        XCTAssertEqual(try lsm.handle(layoutEvent: .feedback(f1), train: train), nil)
    }

    func testLayoutEventSpeed() throws {
        XCTAssertEqual(train.speed, 0)

        let anotherTrain = MockTrainController(route: train.route)
        XCTAssertEqual(try lsm.handle(layoutEvent: .speed(anotherTrain, 10), train: train), nil)
        XCTAssertEqual(train.speed, 0)

        XCTAssertEqual(try lsm.handle(layoutEvent: .speed(train, 7), train: train), .speed(train))
        XCTAssertEqual(train.speed, 7)
    }

    func testLayoutEventTurnout() throws {
        let t1 = Turnout(name: "t1")
        train.state = .running

        XCTAssertEqual(train.adjustSpeedCount, 0)

        train.onUpdateReservedBlocksSettledLength = { _ in
            false
        }
        XCTAssertEqual(try lsm.handle(layoutEvent: .turnout(t1), train: train), nil)
        XCTAssertEqual(train.adjustSpeedCount, 0)

        train.onUpdateReservedBlocksSettledLength = { t in
            t == t1
        }
        XCTAssertEqual(train.adjustSpeedCount, 0)
        XCTAssertEqual(try lsm.handle(layoutEvent: .turnout(t1), train: train), .reservedBlocksSettledLengthChanged(train))
        XCTAssertEqual(train.adjustSpeedCount, 0)
    }

    func testLayoutEventDirection() throws {
        let anotherTrain = MockTrainController(route: train.route)
        anotherTrain.onUpdateReservedBlocks = { true }
        XCTAssertEqual(try lsm.handle(layoutEvent: .direction(anotherTrain), train: train), nil)

        train.onUpdateReservedBlocks = { true }
        XCTAssertEqual(try lsm.handle(layoutEvent: .direction(train), train: train), .reservedBlocksChanged(train))

        train.onUpdateReservedBlocks = { false }
        XCTAssertEqual(try lsm.handle(layoutEvent: .direction(train), train: train), nil)
    }
}
