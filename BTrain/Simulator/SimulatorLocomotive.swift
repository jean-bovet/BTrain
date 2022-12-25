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

// This class defines the locomotive in the simulator: each locomotive in the simulator
// refers to the original locomotive the layout but has its own direction and speed
// that can only be changed via the CommandInterface commands (like a real CS 3).
final class SimulatorLocomotive: ObservableObject, Element {
    let id: Identifier<Locomotive>
    let loc: Locomotive

    @Published var directionForward = true

    // Note: ensure that the speed of the simulated train is decoupled from the train itself
    // to ensure the simulator does not change the speed of the original train directly, but only
    // via commands sent through the interface.
    @Published var speed: SpeedStep = .zero

    struct CurrentBlock {
        let block: Block
        let direction: Direction
        let directionForward: Bool
    }
    
    struct CurrentTurnout {
        let turnout: Turnout
        let fromSocket: Socket
        let toSocket: Socket
    }
    
    /// The block in which the locomotive is located
    @Published var block: CurrentBlock?
    
    /// The turnout in which the locomotive is located
    @Published var turnout: CurrentTurnout?
    
    /// The distance of the locomotive within the block or the turnout
    @Published var distance = 0.0

    init(loc: Locomotive) {
        id = loc.id
        self.loc = loc
        directionForward = loc.directionForward
    }
    
}

