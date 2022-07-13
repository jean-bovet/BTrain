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

@testable import BTrain

extension Layout {
    
    func newRoute(id: String, _ steps: [(String, Direction)]) -> Route {
        newRoute(Identifier<Route>(uuid: id), name: id, steps.map({ step in
            .block(RouteStepBlock(Identifier<Block>(uuid: step.0), step.1))
        }))
    }
    
    func block(_ uuid: String) -> Block {
        block(for: Identifier<Block>(uuid: uuid))!
    }
    
    func block(named name: String) -> Block {
        blocks.first {
            $0.name == name
        }!
    }

    func turnout(_ uuid: String) -> Turnout {
        turnout(for: Identifier<Turnout>(uuid: uuid))!
    }

    func turnout(named name: String) -> Turnout {
        turnouts.first {
            $0.name == name
        }!
    }

    func train(_ uuid: String) -> Train {
        train(for: Identifier<Train>(uuid: uuid))!
    }
    
    func removeTrainGeometry() -> Layout {
        trains.forEach { $0.locomotiveLength = nil; $0.wagonsLength = nil }
        return self
    }
    
    func removeTurnoutGeometry() -> Layout {
        turnouts.forEach { $0.length = nil }
        return self
    }

    func removeBlockGeometry() -> Layout {
        blocks.forEach { block in
            block.length = nil
            for index in block.feedbacks.indices {
                block.feedbacks[index].distance = nil
            }
        }
        return self
    }
    
    func removeTrains() -> Layout {
        removeAllTrains()
        return self
    }

}

extension Array where Element == Block {
    
    func toStrings(useNameInsteadOfId: Bool = true) -> [String] {
        self.map { block in
            "\(useNameInsteadOfId ? block.name : block.id.uuid)"
        }
    }

}
