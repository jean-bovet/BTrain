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

import SwiftUI

struct SimulatorTrainControlView: View {
    
    let simulator: MarklinCommandSimulator
    @ObservedObject var train: SimulatorTrain
    @ObservedObject var speed: TrainSpeed

    var body: some View {
        HStack {
            Toggle("\(train.train.name)", isOn: $train.simulate)

            Group {
                Button {
                    simulator.setTrainDirection(train: train, directionForward: !train.directionForward)
                } label: {
                    if train.directionForward {
                        Image(systemName: "arrowtriangle.right.fill")
                    } else {
                        Image(systemName: "arrowtriangle.left.fill")
                    }
                }.buttonStyle(.borderless)
                
                HStack {
                    Slider(
                        value: $speed.kphAsDouble,
                        in: 0...Double(speed.maxSpeed)
                    ) {
                    } onEditingChanged: { editing in
                        simulator.setTrainSpeed(train: train)
                    }
                    
                    Text("\(Int(speed.kph)) km/h")
                }
            }.disabled(train.simulate == false)
        }
    }
}

private extension TrainSpeed {
    
    // Necessary because SwiftUI Slider requires a Double
    // while speed is UInt16.
    var kphAsDouble: Double {
        get {
            return Double(self.kph)
        }
        set {
            self.kph = UInt16(newValue)
        }
    }
    
}

struct SimulatorTrainControlView_Previews: PreviewProvider {

    static let layout = LayoutACreator().newLayout()
    
    static let simulatorTrain = SimulatorTrain(train: layout.trains[0])
    
    static var previews: some View {
        SimulatorTrainControlView(simulator: MarklinCommandSimulator(layout: layout, interface: MarklinInterface(server: "", port: 0)),
                                  train: simulatorTrain, speed: simulatorTrain.speed)
    }
}
