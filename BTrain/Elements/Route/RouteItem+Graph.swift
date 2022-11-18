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

extension Array where Element == GraphPathElement {
    var toBlockSteps: [RouteItem] {
        toSteps.compactMap { step in
            if case .block = step {
                return step
            } else {
                return nil
            }
        }
    }

    var toSteps: [RouteItem] {
        compactMap { element in
            if let block = element.node as? Block {
                let direction: Direction
                if let entrySocket = element.entrySocket {
                    direction = entrySocket == Block.previousSocket ? .next : .previous
                } else if let exitSocket = element.exitSocket {
                    direction = exitSocket == Block.nextSocket ? .next : .previous
                } else {
                    return nil
                }
                return .block(RouteItemBlock(block, direction))
            } else if let turnout = element.node as? Turnout {
                guard let entrySocket = element.entrySocket else {
                    return nil
                }
                guard let exitSocket = element.exitSocket else {
                    return nil
                }
                return .turnout(RouteItemTurnout(turnout.id, turnout.socket(entrySocket), turnout.socket(exitSocket)))
            } else {
                return nil
            }
        }
    }

    var toResolvedRouteItems: [ResolvedRouteItem] {
        compactMap { element in
            if let block = element.node as? Block {
                let direction: Direction
                if let entrySocket = element.entrySocket {
                    direction = entrySocket == Block.previousSocket ? .next : .previous
                } else if let exitSocket = element.exitSocket {
                    direction = exitSocket == Block.nextSocket ? .next : .previous
                } else {
                    BTLogger.router.error("Missing entry and next socket for \(element, privacy: .public)")
                    return nil
                }

                return .block(.init(block: block, direction: direction))
            } else if let turnout = element.node as? Turnout {
                guard let entrySocket = element.entrySocket else {
                    BTLogger.router.error("Missing entry socket for \(element, privacy: .public)")
                    return nil
                }
                guard let exitSocket = element.exitSocket else {
                    BTLogger.router.error("Missing exit socket for \(element, privacy: .public)")
                    return nil
                }
                return .turnout(.init(turnout: turnout, entrySocketId: entrySocket, exitSocketId: exitSocket))
            } else {
                return nil
            }
        }
    }
}
