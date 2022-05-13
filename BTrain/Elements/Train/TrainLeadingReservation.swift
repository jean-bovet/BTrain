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
    /// Array of leading blocks that have been reserved in front of the train.
    ///
    /// This array is updated by the ``LayoutReservation`` class each time the reserved
    /// blocks are updated. The leading blocks are stored here for quick access instead
    /// of re-computing them on the fly all the time.
    var blocks = [Block]()

    /// Array of leading turnouts that have been reserved in front of the train.
    ///
    /// This array is updated by the ``LayoutReservation`` class each time the reserved
    /// turnouts are updated. The leading turnouts are stored here for quick access instead
    /// of re-computing them on the fly all the time.
    var turnouts = [Turnout]()
    
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
        if turnouts.isEmpty {
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
        // TODO: include turnouts
        let leadingDistance = blocks.reduce(0.0) { partialResult, block in
            if let blockLength = block.length {
                return partialResult + blockLength
            } else {
                return partialResult
            }
        }

        return leadingDistance
    }
    
    func clear() {
        blocks.removeAll()
        turnouts.removeAll()
    }
}
