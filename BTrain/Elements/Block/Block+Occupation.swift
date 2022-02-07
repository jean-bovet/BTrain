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

extension Block {

    // Returns true if the block is reserved and occupied by the train or a portion of the train.
    func isOccupied(by trainId: Identifier<Train>) -> Bool {
        return reserved?.trainId == trainId && train?.trainId == trainId
    }
    
    func canBeReserved(withTrain: Train, direction: Direction) -> Bool {
        guard enabled else {
            return false
        }
        
        guard train == nil else {
            return false
        }
        
        let reservation = Reservation(trainId: withTrain.id, direction: direction)
        guard reserved == nil || reserved == reservation else {
            return false
        }
        
        return true
    }
    
    // Returns the length (in cm) of the part at the specified index,
    // starting from the beginning of the block.
    func partLenght(at index: Int) throws -> Double? {
        if index == feedbacks.count {
            // Last part:
            // [ p0  |   p1 |   p2 ]
            // [ <0> f1 <1> f2 <2> ]
            // |<--distance->|
            // |<--- length ------>|
            guard let length = length else {
                return nil
            }
            guard let feedbackDistance = feedbacks[index - 1].distance else {
                return nil
            }
            return length - feedbackDistance
        } else if index > 0 {
            // [ p0  |   p1 |   p2 ]
            // [ <0> f1 <1> f2 <2> ]
            // |<--distance->|
            // |<-d->|
            guard let feedback1Distance = feedbacks[index].distance else {
                return nil
            }
            guard let feedback2Distance = feedbacks[index - 1].distance else {
                return nil
            }
            return feedback1Distance - feedback2Distance
        } else if index == 0 {
            // First part:
            // [ p0  |   p1 |   p2 ]
            // [ <0> f1 <1> f2 <2> ]
            // |<-d->|
            return feedbacks[index].distance
        } else {
            throw LayoutError.invalidPartIndex(index: index, block: self)
        }

    }
    
    // Returns all the part lenght (in cm) for the entire block or nil
    // if one (or more) feedback distance is not defined.
    func allPartsLength() throws -> [Int:Double]? {
        var results = [Int:Double]()
        for index in 0...feedbacks.count {
            if let length = try partLenght(at: index) {
                results[index] = length
            } else {
                return nil
            }
        }
        return results
    }
    
}
