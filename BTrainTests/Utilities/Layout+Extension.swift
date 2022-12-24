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

extension Layout {
    func newRoute(id: String, _ steps: [(String, Direction)]) -> Route {
        newRoute(Identifier<Route>(uuid: id), name: id, steps.map { step in
            .block(RouteItemBlock(Identifier<Block>(uuid: step.0), step.1))
        })
    }

    func route(named name: String) -> Route {
        routes.first {
            $0.name == name
        }!
    }

    func block(_ uuid: String) -> Block {
        blocks[Identifier<Block>(uuid: uuid)]!
    }

    func block(named name: String) -> Block {
        blocks.elements.first {
            $0.name == name
        }!
    }

    func turnout(_ uuid: String) -> Turnout {
        turnouts[Identifier<Turnout>(uuid: uuid)]!
    }

    func turnout(named name: String) -> Turnout {
        turnouts.elements.first {
            $0.name == name
        }!
    }

    func feedback(named name: String) -> Feedback {
        feedbacks.elements.first {
            $0.name == name
        }!
    }

    func train(_ uuid: String) -> Train {
        trains[Identifier<Train>(uuid: uuid)]!
    }

    func removeTrainGeometry() -> Layout {
        trains.elements.forEach { $0.wagonsLength = nil }
        locomotives.elements.forEach { $0.length = nil }
        return self
    }

    func removeTurnoutGeometry() -> Layout {
        turnouts.elements.forEach { $0.length = nil }
        return self
    }

    func removeBlockGeometry() -> Layout {
        blocks.elements.forEach { block in
            block.length = nil
            for index in block.feedbacks.indices {
                block.feedbacks[index].distance = nil
            }
        }
        return self
    }

    @discardableResult
    func removeTrains() -> Layout {
        trains.elements.forEach {
            try? remove(trainId: $0.id)
        }
        return self
    }

    func reserve(_ block: String, with train: String, direction: Direction) {
        blocks[Identifier<Block>(uuid: block)]?.reservation = Reservation(trainId: Identifier<Train>(uuid: train), direction: direction)
    }

    func free(_ block: String) {
        blocks[Identifier<Block>(uuid: block)]?.reservation = nil
    }

    func bestPath(from: String, fromDirection: Direction = .next, toReachBlock toBlockName: String? = nil, toDirection: Direction? = nil, reservedBlockBehavior: PathFinder.Constraints.ReservedBlockBehavior, shortestPath: Bool = true) throws -> GraphPath? {
        setTrain(train: trains[0], toBlockNamed: from, direction: fromDirection)
        let toBlock = (toBlockName != nil) ? block(named: toBlockName!) : nil
        return try bestPath(ofTrain: trains[0], toReachBlock: toBlock, withDirection: toDirection, reservedBlockBehavior: reservedBlockBehavior, shortestPath: shortestPath)
    }

    func assertShortPath(_ from: (String, Direction), _ to: (String, Direction), _ expectedPath: [String]) throws {
        // Note: it is important to remove all the trains from the layout to avoid unexpected reserved blocks!
        let layout = removeTrains()

        // Let's use a brand new train
        let train = Train(id: Identifier<Train>(uuid: "foo"), name: "foo")
        train.locomotive = layout.locomotives[0]

        let fromBlock = layout.block(named: from.0)
        let toBlock = layout.block(named: to.0)

        setTrain(train: train, toBlockNamed: fromBlock.name, direction: from.1)
        let path = try layout.bestPath(ofTrain: train, toReachBlock: toBlock, withDirection: to.1, reservedBlockBehavior: .avoidReserved, shortestPath: true)!
        XCTAssertEqual(path.toStrings, expectedPath)
    }

    private func setTrain(train: Train, toBlockNamed blockName: String, direction: Direction = .next) {
        let block = block(named: blockName)

        train.block = block
        block.trainInstance = .init(train.id, direction)
    }
}

extension Array where Element == Block {
    func toStrings(useNameInsteadOfId: Bool = true) -> [String] {
        map { block in
            "\(useNameInsteadOfId ? block.name : block.id.uuid)"
        }
    }
}
