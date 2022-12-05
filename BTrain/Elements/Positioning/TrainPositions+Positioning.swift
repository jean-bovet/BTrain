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

extension TrainPositions {

    func newPositionsWith(trainMovesForward: Bool, detectedPosition: TrainPosition, reservation: Train.Reservation) throws -> TrainPositions {
        var newLocation = self
        
        if trainMovesForward {
            //         Block Natural Direction: ────────▶  ────────▶                    ────────▶  ◀────────
            //        Train Direction In Block: ─ ─ ─ ─ ▶  ─ ─ ─ ─ ▶                    ─ ─ ─ ─ ▶  ─ ─ ─ ─ ▶
            //                                 ┌─────────┐┌─────────┐┌ ─ ─ ─ ─ ┐       ┌─────────┐┌─────────┐┌ ─ ─ ─ ─ ┐
            //                                 │   b1    ││   b2    │   lead           │   b1    ││   b2    │   lead
            //                                 └─────────┘└─────────┘└ ─ ─ ─ ─ ┘       └─────────┘└─────────┘└ ─ ─ ─ ─ ┘
            //                 Block Positions:  0  1  2    0  1  2                      0  1  2    2  1  0
            //
            //       Train (direction forward):   ■■■■■■■■■■■■■▶                          ■■■■■■■■■■■■■▶
            //               Occupied: [b2, b1]   b            f                          b            f
            //
            //       Train (direction forward):   ◀■■■■■■■■■■■■■                          ◀■■■■■■■■■■■■■
            //               Occupied: [b1, b2]   f            b                          f            b
            newLocation.back = nil
            if front == nil {
                newLocation.front = detectedPosition
            } else if let front = front {
                if try detectedPosition.isAfter(front, reservation: reservation) {
                    newLocation.front = detectedPosition
                }
            }
        } else {
            //         Block Natural Direction: ────────▶  ────────▶                    ────────▶  ◀────────
            //        Train Direction In Block: ─ ─ ─ ─ ▶  ─ ─ ─ ─ ▶                    ─ ─ ─ ─ ▶  ─ ─ ─ ─ ▶
            //                                 ┌─────────┐┌─────────┐┌ ─ ─ ─ ─ ┐       ┌─────────┐┌─────────┐┌ ─ ─ ─ ─ ┐
            //                                 │   b1    ││   b2    │   lead           │   b1    ││   b2    │   lead
            //                                 └─────────┘└─────────┘└ ─ ─ ─ ─ ┘       └─────────┘└─────────┘└ ─ ─ ─ ─ ┘
            //                 Block Positions:  0  1  2    0  1  2                      0  1  2    2  1  0
            //
            //      Train (direction backward):   ▶■■■■■■■■■■■■■                          ▶■■■■■■■■■■■■■
            //               Occupied: [b2, b1]   f            b                          f            b
            //
            //      Train (direction backward):   ■■■■■■■■■■■■■◀                          ■■■■■■■■■■■■■◀
            //               Occupied: [b1, b2]   b            f                          b            f
            newLocation.front = nil
            if back == nil {
                newLocation.back = detectedPosition
            } else if let back = back {
                if try detectedPosition.isAfter(back, reservation: reservation) {
                    newLocation.back = detectedPosition
                }
            }
        }

        return newLocation
    }
    
}
