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
    let iconManager: LocomotiveIconManager
    let simulator: MarklinCommandSimulator
    @ObservedObject var simLoc: SimulatorLocomotive

    var body: some View {
        HStack {
            LocomotiveIconView(locomotiveIconManager: iconManager, loc: simLoc.loc, size: .small, hideIfNotDefined: true)

            VStack(alignment: .leading) {
                Text(simLoc.loc.name)
                HStack {
                    if let block = simLoc.block {
                        Text("\(block.block.name)")
                    } else if let turnout = simLoc.turnout {
                        Text("\(turnout.turnout.name)")
                    } else {
                        Text("?")
                    }
                    Text("\(simLoc.distance.distanceString)")
                }.font(.caption)
            }

            Group {
                Button {
                    simulator.setLocomotiveDirection(locomotive: simLoc, directionForward: !simLoc.directionForward)
                } label: {
                    if simLoc.directionForward {
                        Image(systemName: "arrowtriangle.right.fill")
                    } else {
                        Image(systemName: "arrowtriangle.left.fill")
                    }
                }.buttonStyle(.borderless)

                HStack {
                    Slider(
                        value: $simLoc.speedAsDouble,
                        in: 0 ... Double(simLoc.loc.decoder.steps)
                    ) {} onEditingChanged: { _ in
                        simulator.setLocomotiveSpeed(locomotive: simLoc)
                    }

                    Text("\(Int(simLoc.speed.value)) steps")
                        .padding(.trailing)
                }
            }
        }
    }
}

private extension SimulatorLocomotive {
    // Necessary because SwiftUI Slider requires a Double
    // while speed is UInt16.
    var speedAsDouble: Double {
        get {
            Double(speed.value)
        }
        set {
            speed.value = UInt16(newValue)
        }
    }
}

struct SimulatorTrainControlView_Previews: PreviewProvider {
    static let layout = LayoutLoop1().newLayout()

    static let simulatorTrain = SimulatorLocomotive(loc: layout.locomotives[0])

    static var previews: some View {
        SimulatorTrainControlView(iconManager: LocomotiveIconManager(), simulator: MarklinCommandSimulator(layout: layout, interface: MarklinInterface()),
                                  simLoc: simulatorTrain)
    }
}
