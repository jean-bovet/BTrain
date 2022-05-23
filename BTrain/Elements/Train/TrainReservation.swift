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

/// Keep track of the reserved block and turnout
class TrainReservation {
    enum Item: Equatable {
        case block(Block)
        case turnout(Turnout)
    }
    
    /// Array of reservation items
    /// This array is updated by the ``LayoutReservation`` class each time the reserved
    /// blocks or turnouts are updated.
    internal var items = [Item]()
    
    /// Returns true if there are no blocks nor turnout reserved
    var isEmpty: Bool {
        items.isEmpty
    }
    
    /// Array of reserved blocks.
    var blocks: [Block] {
        items.compactMap { item in
            if case .block(let block) = item {
                return block
            } else {
                return nil
            }
        }
    }
    
    /// Array of reserved turnouts.
    var turnouts: [Turnout] {
        items.compactMap { item in
            if case .turnout(let turnout) = item {
                return turnout
            } else {
                return nil
            }
        }
    }
    
    func append(_ block: Block) {
        items.append(.block(block))
    }
    
    func append(_ turnout: Turnout) {
        items.append(.turnout(turnout))
    }

    func clear() {
        items.removeAll()
    }

}

/// This class keeps track of the occupied reserved blocks or turnouts for a specific train.
///
/// An occupied block or turnout is one that contains a portion of the train, either the locomotive or a wagon.
final class TrainOccupiedReservation: TrainReservation {
    
}

/// This class keeps track of the leading reservation items assigned to this train.
///
/// A reservation item can be a block or a turnout. This is very useful in order to ensure
/// the train moves only when there are reserved blocks ahead and when the reserved
/// turnouts have settled (that is, the turnout state has changed in the physical layout).
final class TrainLeadingReservation: TrainReservation {
    
    /// Returns true if there are reserved blocks (and turnouts) **and** they are settled.
    ///
    /// Note: *settled* means the turnout actual state is equal to the expected state, in other word,
    /// the turnout has effectively changed on the physical layout to the best of our knowledge.
    var reservedAndSettled: Bool {
        if blocks.isEmpty {
            return false
        }
        
        return emptyOrSettled
    }
    
    /// Returns true if there are no leading blocks or if there are blocks (and turnouts) **and** they are settled.
    ///
    /// Note: *settled* means the turnout actual state is equal to the expected state, in other word,
    /// the turnout has effectively changed on the physical layout to the best of our knowledge.
    var emptyOrSettled: Bool {
        if blocks.isEmpty {
            return true
        }
        
        for turnout in turnouts {
            if !turnout.settled {
                return false
            }
        }

        return true
    }
        
    /// Returns the distance that has been settled. In other words, returns the distance
    /// that contains only consecutives elements (blocks and turnouts) that have settled.
    ///
    /// When turnout takes some time to change state, the leading distance might be less
    /// than the total leading distance which must be accounted for in order for the train
    /// to not use the un-settled turnout otherwise they will be taking a wrong path!
    var settledDistance: Double {
        var distance = 0.0
        for item in items {
            switch item {
            case .block(let block):
                if let blockLength = block.length {
                    distance += blockLength
                }
            case .turnout(let turnout):
                if !turnout.settled {
                    return distance
                }
                
                if let turnoutLength = turnout.length {
                    distance += turnoutLength
                }
            }
        }
        return distance
    }

}
