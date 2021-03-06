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

struct RouteItemStation: Equatable, Codable {
    
    static func ==(lhs: RouteItemStation, rhs: RouteItemStation) -> Bool {
        lhs.id == rhs.id
    }

    var id = UUID().uuidString

    var stationId: Identifier<Station>
    
    var description: String {
        "\(stationId)"
    }
        
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

    func elementFor(direction: Direction, block: Block) -> GraphPathElement {
        let entrySocket = direction == .next ? Block.previousSocket : Block.nextSocket
        let exitSocket = direction == .next ? Block.nextSocket : Block.previousSocket
        return GraphPathElement(node: block, entrySocket:  entrySocket, exitSocket: exitSocket)
    }
    
    func bestElement(station: Station, constraints: PathFinder.Constraints) -> Station.StationElement? {
        if let element = elementWithTrain(station: station, train: constraints.train, layout: constraints.layout) {
            return element
        }
        
        if let element = firstAvailableElement(station: station, constraints: constraints) {
            return element
        }
        
        return nil
    }
    
    func firstAvailableElement(station: Station, constraints: PathFinder.Constraints) -> Station.StationElement? {
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
    
    func elementWithTrain(station: Station, train: Train, layout: Layout) -> Station.StationElement? {
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
