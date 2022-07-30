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

extension RouteItem {
    
    var stepBlockId: Identifier<Block>? {
        if case .block(let stepBlock) = self {
            return stepBlock.blockId
        } else {
            return nil
        }
    }
    
    var stepTurnoutId: Identifier<Turnout>? {
        if case .turnout(let stepTurnout) = self {
            return stepTurnout.turnoutId
        } else {
            return nil
        }
    }
        
}

extension Array where Element == RouteItem {
    
    func toStrings(_ layout: Layout, useNameInsteadOfId: Bool = true) -> [String] {
        self.map { step in
            switch step {
            case .block(let stepBlock):
                if let block = layout.block(for: stepBlock.blockId) {
                    return "\(useNameInsteadOfId ? block.name : block.id.uuid):\(stepBlock.direction)"
                } else {
                    return "\(stepBlock.blockId.uuid):\(stepBlock.direction)"
                }
            case .turnout(let stepTurnout):
                if let turnout = layout.turnout(for: stepTurnout.turnoutId) {
                    return "\(useNameInsteadOfId ? turnout.name : turnout.id.uuid):(\(stepTurnout.entrySocket.socketId!)>\(stepTurnout.exitSocket.socketId!))"
                } else {
                    return "\(stepTurnout.turnoutId.uuid):(\(stepTurnout.entrySocket.socketId!)>\(stepTurnout.exitSocket.socketId!))"
                }
            case .station(let stepStation):
                if let station = layout.station(for: stepStation.stationId) {
                    return "\(useNameInsteadOfId ? station.name : station.id.uuid)"
                } else {
                    return "\(stepStation.stationId.uuid)"
                }
            }
        }
    }

}

extension Array where Element == ResolvedRouteItem {
    
    func toStrings(useNameInsteadOfId: Bool = true) -> [String] {
        self.map { step in
            switch step {
            case .block(let stepBlock):
                return "\(useNameInsteadOfId ? stepBlock.block.name : stepBlock.block.id.uuid):\(stepBlock.direction)"
            case .turnout(let stepTurnout):
                return "\(useNameInsteadOfId ? stepTurnout.turnout.name : stepTurnout.turnout.id.uuid):(\(stepTurnout.entrySocketId)>\(stepTurnout.exitSocketId))"
            }
        }
    }

}
