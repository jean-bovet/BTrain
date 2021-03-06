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

// This class defines the train in the simulator: each train in the simulator
// refers to the original train the layout but has its own direction and speed
// that can only be changed via the CommandInterface commands (like a real CS 3).
final class SimulatorTrain: ObservableObject, Element {
    let id: Identifier<Train>
    let train: Train
    
    @Published var simulate = true
    @Published var directionForward = true
    
    // Note: ensure that the speed of the simulated train is decoupled from the train itself
    // to ensure the simulator does not change the speed of the original train directly, but only
    // via commands sent through the interface.
    @Published var speed: SpeedStep = .zero
        
    init(train: Train) {
        self.id = train.id
        self.train = train
        self.directionForward = train.directionForward
    }
}
