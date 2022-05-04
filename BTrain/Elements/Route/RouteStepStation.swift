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

struct RouteStepStation: RouteStep, Equatable, Codable {
    
    static func ==(lhs: RouteStepStation, rhs: RouteStepStation) -> Bool {
        return lhs.id == rhs.id
    }

    var id = UUID().uuidString

    var stationId: Identifier<Station>
    
    var description: String {
        return "\(stationId)"
    }
        
    func resolve(_ constraints: GraphPathFinderConstraints, _ context: GraphPathFinderContext) -> GraphPathElement? {
        guard let lc = context as? LayoutPathFinder.LayoutContext else {
            return nil
        }
        guard let station = lc.layout.station(for: stationId) else {
            return nil
        }
        
        guard let element = firstAvailableElement(station: station, train: lc.train, layout: lc.layout) else {
            return nil
        }
        
        guard let block = lc.layout.block(for: element.blockId) else {
            return nil
        }
        
        let direction = element.direction ?? .next
        
//        guard let direction = element.direction else {
//            // TODO: support direction being nil, which means two elements can be returned, one for each direction
//            return nil
//        }
        let entrySocket = direction == .next ? Block.previousSocket : Block.nextSocket
        let exitSocket = direction == .next ? Block.nextSocket : Block.previousSocket
        return .init(node: block, entrySocket:  entrySocket, exitSocket: exitSocket)
    }
    
    func firstAvailableElement(station: Station, train: Train, layout: Layout) -> Station.StationElement? {
        for element in station.elements {
            guard let block = layout.block(for: element.blockId) else {
                continue
            }
            if block.enabled && (block.reserved == nil || block.reserved?.trainId == train.id) {
                return element
            }
        }
        return nil
    }
}
