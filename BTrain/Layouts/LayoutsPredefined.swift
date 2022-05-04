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

final class LayoutBlankCreator: LayoutCreating {
    static var id: Identifier<Layout> {
        return Identifier<Layout>(uuid: "Empty Layout")
    }
    
    func newLayout() -> Layout {
        return Layout(id: LayoutBlankCreator.id)
    }
    
}

//┌─────────┐           ┌──────┐   ┌──────┐  ┌──────┐            ┌──────┐
//│    A    │──▶  AB  ─▶│  B   │──▶│  C   │─▶│  D   │──▶  DE  ──▶│  E   │
//└─────────┘           └──────┘   └──────┘  └──────┘            └──────┘
//                 │                                       ▲
//                 │    ┌──────┐   ┌──────┐  ┌──────┐      │
//                 └───▶│  B2  │──▶│ !C2  │─▶│  D2  │──────┘
//                      └──────┘   └──────┘  └──────┘
final class LayoutPointToPoint: LayoutCreating {
    
    static let id = Identifier<Layout>(uuid: "Point to Point")
    
    func newLayout() -> Layout {
        LayoutFactory.layoutFromBundle(named: LayoutPointToPoint.id.uuid)
    }
}

final class LayoutPointToLoop: LayoutCreating {
    
    static let id = Identifier<Layout>(uuid: "Point to Loop")
    
    func newLayout() -> Layout {
        LayoutFactory.layoutFromBundle(named: LayoutPointToLoop.id.uuid)
    }
    
}

final class LayoutLoopToLoop: LayoutCreating {
    
    static let id = Identifier<Layout>(uuid: "Loop to Loop")
    
    func newLayout() -> Layout {
        LayoutFactory.layoutFromBundle(named: LayoutLoopToLoop.id.uuid)
    }
    
}

//   ┌─────────┐                              ┌─────────┐
//┌──│ Block 2 │◀────┐         ┌─────────────▶│ Block 4 │──┐
//│  └─────────┘     │         │              └─────────┘  │
//│                  │         │                           │
//│                  │                                     │
//│                  └─────Turnout12◀───┐                  │
//│                                     │                  │
//│                            ▲        │                  │
//│  ┌─────────┐               │        │     ┌─────────┐  │
//└─▶│ Block 3 │───────────────┘        └─────│ Block 1 │◀─┘
//   └─────────┘                              └─────────┘
final class LayoutFigure8: LayoutCreating {
    
    static let id = Identifier<Layout>(uuid: "Figure 8")
    
    func newLayout() -> Layout {
        LayoutFactory.layoutFromBundle(named: LayoutFigure8.id.uuid)
    }
    
}

//                 ┌─────────┐
//┌────────────────│ Block 2 │◀────────────────────┐
//│                └─────────┘                     │
//│                                                │
//│                                                │
//│                ┌─────────┐
//│       ┌───────▶│ Block 3 │────────────────▶Turnout12
//│       │        └─────────┘
//│       │                                        ▲
//│       │                                        │
//│                                 ┌─────────┐    │
//└─▶Turnout21 ────────────────────▶│ Block 1 │────┘
//                                  └─────────┘
final class LayoutLoop1: LayoutCreating {

    static let id = Identifier<Layout>(uuid: "Loop 1")
        
    func newLayout() -> Layout {
        LayoutFactory.layoutFromBundle(named: LayoutLoop1.id.uuid)
    }
        
}

//                            ┌─────────┐
//     ┌───▶   t125   ───────▶│ Block 2 │───────────────────────────┐
//     │                      └─────────┘                           │
//     │         ▲                                                  │
//     │         │                                                  │
//┌─────────┐    │                                                  ▼
//│ Block 1 │    │             ┌─────────┐                     ┌─────────┐
//└─────────┘    └─────────────│ Block 5 │◀──────────────┐     │ Block 3 │
//     ▲                       └─────────┘               │     └─────────┘
//     │                                                 │          │
//     │                                                 │          │
//     │                                                 │          │
//     │                                                 │          │
//     │                       ┌─────────┐                          │
//     └───────────────────────│ Block 4 │◀─────────   t345   ◀─────┘
//                             └─────────┘
final class LayoutLoop2: LayoutCreating {
    
    static let id = Identifier<Layout>(uuid: "Loop 2")
    
    func newLayout() -> Layout {
        LayoutFactory.layoutFromBundle(named: LayoutLoop2.id.uuid)
    }
    
}

//    ┌─────────┐                      ┌─────────┐             ┌─────────┐
//    │   s1    │───▶  t1  ───▶  t2  ─▶│   b1    │─▶  t4  ────▶│   s2    │
//    └─────────┘                      └─────────┘             └─────────┘
//         ▲            │         │                    ▲            │
//         │            │         │                    │            │
//         │            ▼         ▼                    │            │
//         │       ┌─────────┐                    ┌─────────┐       │
//         │       │   b2    │─▶ t3  ────────────▶│   b3    │       │
//         │       └─────────┘                    └─────────┘       ▼
//    ┌─────────┐                                              ┌─────────┐
//    │   b5    │◀─────────────────────────────────────────────│   b4    │
//    └─────────┘                                              └─────────┘
final class LayoutLoopWithStation: LayoutCreating {
    
    static let id = Identifier<Layout>(uuid: "Loop with Station")
    
    func newLayout() -> Layout {
        LayoutFactory.layoutFromBundle(named: LayoutLoopWithStation.id.uuid)
    }
}

/// Similar to ``LayoutLoopWithStation`` but with stations defined
/// - Station N: n1, n2
/// - Station S: s1, s2
final class LayoutLoopWithStations: LayoutCreating {
    
    static let id = Identifier<Layout>(uuid: "Loop with Stations")
    
    func newLayout() -> Layout {
        LayoutFactory.layoutFromBundle(named: LayoutLoopWithStations.id.uuid)
    }
}

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
    
    static let id = Identifier<Layout>(uuid: "Complex Loop")
    
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
        LayoutFactory.layoutFromBundle(named: LayoutComplexLoop.id.uuid)
    }
    
}

final class LayoutComplex: LayoutCreating {
    
    static let id = Identifier<Layout>(uuid: "Complex Layout")

    func newLayout() -> Layout {
        LayoutFactory.layoutFromBundle(named: LayoutComplex.id.uuid)
    }
    
}

// This layout contains two blocks and one turnout that are
// not linked together. It is used for unit tests and functional testing
//┌─────────┐                              ┌─────────┐
//│ Block 1 │           Turnout12          │ Block 2 │
//└─────────┘                              └─────────┘
final class LayoutIncomplete: LayoutCreating {
    
    static let id = Identifier<Layout>(uuid: "Incomplete Layout")
    
    func newLayout() -> Layout {
        let l = Layout(uuid: LayoutIncomplete.id.uuid)
        l.name = LayoutIncomplete.id.uuid

        // Blocks
        let b1 = l.newBlock(name: "1", category: .free)
        b1.center = CGPoint(x: 100, y: 100)

        let b2 = l.newBlock(name: "2", category: .free)
        b2.center = CGPoint(x: 300, y: 100)

        // Feedbacks
        let f11 = Feedback("f11", deviceID: 1, contactID: 1)
        let f12 = Feedback("f12", deviceID: 1, contactID: 2)
        let f21 = Feedback("f21", deviceID: 2, contactID: 1)
        let f22 = Feedback("f22", deviceID: 2, contactID: 2)
        l.assign(b1, [f11, f12])
        l.assign(b2, [f21, f22])

        // Turnouts
        let t = l.newTurnout(name: "0", category: .singleRight)
        t.center = CGPoint(x: 200, y: 100)
        
        // Train
        l.newTrain()
        l.newTrain()

        // Routes
        _ = l.newRoute(Identifier<Route>(uuid: "0"), name: "Simple Route",
                       [.block(RouteStepBlock(b1, .next)), .block(RouteStepBlock(b2, .next))])
        
        return l
    }
    
}
