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
            //               Occupied: [b2, b1]   t            h                          t            h
            //
            //       Train (direction forward):   ◀■■■■■■■■■■■■■                          ◀■■■■■■■■■■■■■
            //               Occupied: [b1, b2]   h            t                          h            t
            newLocation.tail = nil
            if let head = head {
                if try detectedPosition.isAfter(head, reservation: reservation) {
                    newLocation.head = detectedPosition
                }
            } else {
                newLocation.head = detectedPosition
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
            //               Occupied: [b2, b1]   h            t                         h            t
            //
            //      Train (direction backward):   ■■■■■■■■■■■■■◀                          ■■■■■■■■■■■■■◀
            //               Occupied: [b1, b2]   t            h                          t            h
            newLocation.head = nil
            if let tail = tail {
                if try detectedPosition.isAfter(tail, reservation: reservation) {
                    newLocation.tail = detectedPosition
                }
            } else {
                newLocation.tail = detectedPosition
            }
        }

        return newLocation
    }
}
