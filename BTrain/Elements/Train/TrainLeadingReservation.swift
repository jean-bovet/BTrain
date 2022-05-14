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

/// This class keeps track of the leading reservation items assigned to this train.
///
/// A reservation item can be a block or a turnout. This is very useful in order to ensure
/// the train moves only when there are reserved blocks ahead and when the reserved
/// turnouts have settled (that is, the turnout state has changed in the physical layout).
final class TrainLeadingReservation {
    
    enum Item {
        case block(Block)
        case turnout(Turnout)
    }
    
    /// Array of leading reservation items
    /// This array is updated by the ``LayoutReservation`` class each time the reserved
    /// blocks or turnouts are updated.
    private var items = [Item]()

    /// Array of leading blocks that have been reserved in front of the train.
    var blocks: [Block] {
        items.compactMap { item in
            if case .block(let block) = item {
                return block
            } else {
                return nil
            }
        }
    }
    
    /// Array of leading turnouts that have been reserved in front of the train.
    var turnouts: [Turnout] {
        items.compactMap { item in
            if case .turnout(let turnout) = item {
                return turnout
            } else {
                return nil
            }
        }
    }
    
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
            if turnout.requestedState != turnout.actualState {
                return false
            }
        }

        return true
    }
    
    var distance: Double {
        let leadingDistance = items.reduce(0.0) { partialResult, item in
            switch item {
            case .block(let block):
                if let blockLength = block.length {
                    return partialResult + blockLength
                } else {
                    return partialResult
                }
            case .turnout(let turnout):
                if let turnoutLength = turnout.length {
                    return partialResult + turnoutLength
                } else {
                    return partialResult
                }
            }
        }

        return leadingDistance
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
