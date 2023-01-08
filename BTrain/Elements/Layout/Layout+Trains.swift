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

extension Layout {
    @discardableResult
    func newTrain() -> Train {
        let id = LayoutIdentity.newIdentity(trains.elements, prefix: .train)
        return trains.add(Train(id: id, name: id.uuid))
    }

    @discardableResult
    func duplicate(train: Train) -> Train {
        let nt = Train(name: "\(train.name) copy")
        nt.routeId = train.routeId
        nt.locomotive = train.locomotive
        nt.wagonsLength = train.wagonsLength
        nt.maxNumberOfLeadingReservedBlocks = train.maxNumberOfLeadingReservedBlocks
        nt.blocksToAvoid = train.blocksToAvoid
        nt.turnoutsToAvoid = train.turnoutsToAvoid
        return trains.add(nt)
    }

    func delete(trainId: Identifier<Train>) {
        try? remove(trainId: trainId)
        trains.remove(trainId)
    }

    // Remove the train from the layout (but not from the list of train)
    func remove(trainId: Identifier<Train>) throws {
        guard let train = trains[trainId] else {
            throw LayoutError.trainNotFound(trainId: trainId)
        }

        // Remove the train from the blocks
        blocks.elements
            .filter { $0.reservation?.trainId == train.id }
            .forEach { block in
                block.reservation = nil
                block.trainInstance = nil
            }
        turnouts.elements.filter { $0.reserved?.train == train.id }.forEach { $0.reserved = nil; $0.train = nil }
        transitions.elements.filter { $0.reserved == train.id }.forEach { $0.reserved = nil; $0.train = nil }

        train.positions.clear()
        train.occupied.clear()
    }

    /// Removes from the layout any train that does not have a defined positions. This happens with
    /// older layout that did not have a well defined positions associated with the train but relied
    /// on a single block for the positioning.
    /// Note: it is up to the user to add, manually, the train to the layout again.
    func removeOrphanedTrains() {
        for train in trains.elements.filter({ $0.positions.defined == false }) {
            try? remove(trainId: train.id)
        }
    }

    func block(for train: Train, step: RouteItem) -> (Identifier<Block>, Direction)? {
        switch step {
        case let .block(stepBlock):
            return (stepBlock.blockId, stepBlock.direction)

        case let .station(stepStation):
            guard let station = stations[stepStation.stationId] else {
                return nil
            }
            guard let item = station.blockWith(train: train, layout: self) else {
                return nil
            }

            guard let bid = item.blockId, let bd = item.direction else {
                return nil
            }

            return (bid, bd)

        case .turnout:
            return nil
        }
    }
}
