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

extension RouteItem: Resolvable {
    
    func resolve(_ constraints: PathFinder.Constraints) -> [GraphPathElement]? {
        switch self {
        case .block(let block): return block.resolve(constraints)
        case .turnout(let turnout): return turnout.resolve(constraints)
        case .station(let station): return station.resolve(constraints)
        }
    }
    
}

extension RouteItemBlock: Resolvable {
    func resolve(_ constraints: PathFinder.Constraints) -> [GraphPathElement]? {
        guard let block = constraints.layout.block(for: blockId) else {
            return nil
        }
        
        var resolvedElement = GraphPathElement.direction(block, direction)
        resolvedElement.sourceIdentifier = sourceIdentifier
        return [resolvedElement]
    }
}

extension RouteItemTurnout: Resolvable {
    func resolve(_ constraints: PathFinder.Constraints) -> [GraphPathElement]? {
        guard let turnout = constraints.layout.turnout(for: turnoutId) else {
            return nil
        }
        return [GraphPathElement(node: turnout, entrySocket: entrySocket.socketId, exitSocket: exitSocket.socketId)]

    }
}

extension RouteItemStation: Resolvable {
    
    func resolve(_ constraints: PathFinder.Constraints) -> [GraphPathElement]? {
        guard let station = constraints.layout.station(for: stationId) else {
            return nil
        }
                
        guard let element = bestElement(station: station, constraints: constraints) else {
            return nil
        }
        
        guard let block = constraints.layout.block(for: element.blockId) else {
            return nil
        }
        
        if let direction = element.direction {
            return [GraphPathElement.direction(block, direction)]
        } else {
            return [GraphPathElement.direction(block, .next), GraphPathElement.direction(block, .previous)]
        }
    }

    private func bestElement(station: Station, constraints: PathFinder.Constraints) -> Station.StationElement? {
        if let element = elementWithTrain(station: station, train: constraints.train, layout: constraints.layout) {
            return element
        }
        
        if let element = firstAvailableElement(station: station, constraints: constraints) {
            return element
        }
        
        return nil
    }
    
    private func firstAvailableElement(station: Station, constraints: PathFinder.Constraints) -> Station.StationElement? {
        for element in station.elements {
            guard let block = constraints.layout.block(for: element.blockId) else {
                continue
            }
            
            guard block.enabled else {
                continue
            }
            
            if constraints.reservedBlockBehavior == .ignoreReserved {
                return element
            } else if block.reservation == nil || block.reservation?.trainId == constraints.train.id {
                return element
            }
        }
        return nil
    }
    
    private func elementWithTrain(station: Station, train: Train, layout: Layout) -> Station.StationElement? {
        for element in station.elements {
            guard let block = layout.block(for: element.blockId) else {
                continue
            }
            if block.id == train.blockId {
                return element
            }
        }
        return nil
    }

}
