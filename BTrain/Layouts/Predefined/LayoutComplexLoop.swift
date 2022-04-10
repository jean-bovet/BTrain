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

//              t3               ┌─────────┐              t4
//     ┌─────▶––––––––––────────▶│ Block 2 │─────────────▶––––––––––───────┐
//     │          \              └─────────┘                   /           │
//     │           ▲                                           │           │
//     │           │                                           │           ▼
//┌─────────┐      │             ┌─────────┐                   │      ┌─────────┐
//│ Block 1 │      └─────────────│ Block 5 │◀──────────────┐   │      │ Block 3 │
//└─────────┘                    └─────────┘               │   │      └─────────┘
//     ▲                                                   │   │           │
//     │                         ┌─────────┐               │   │           │
//     │            ┌────────────│ Block 6 │◀──────────────┼───┘           │
//     │            │            └─────────┘               │               ▼
//     │            ▼                                      │              |
//  t2 |        t8  /            ┌─────────┐           t7  \              |
//     |\  ◀───––––––––––◀───────│ Block 4 │◀─────────––––––––––◀─────── /| t5
//     |                         └─────────┘
//     ▲                                                                   │
//     │                                                                   │
//     │                         ┌─────────┐                               │
//     │            ┌────────────│   S1    │◀───────────┐                  │
//     │            │            └─────────┘            │                  │
//     │            ▼                                   │                  │
//     │           / t1          ┌─────────┐       t6   \                  │
//     └───────── –––– ◀─────────│   S2    │◀──────––––––––––◀─────────────┘
//                               └─────────┘
final class LayoutComplexLoop: LayoutCreating {
    
    static let id = Identifier<Layout>(uuid: "layout-e")

    var name: String {
        return "Complex Loop"
    }
    
    func newLayoutWithLengths(_ l: Layout) -> Layout {
        l.trains.forEach {
            $0.locomotiveLength = 20
            $0.wagonsLength = 80
        }
        l.blocks.forEach { block in
            block.length = 60
            let fbDistanceIncrement = 60.0 / Double(block.feedbacks.count+1)
            var fbDistance = fbDistanceIncrement
            for index in block.feedbacks.indices {
                block.feedbacks[index].distance = fbDistance
                fbDistance += fbDistanceIncrement
            }
        }
        return l
    }
    
    func newLayout() -> Layout {
        LayoutFactory.layoutFromBundle(named: "Complex Loop")
    }
    
}
