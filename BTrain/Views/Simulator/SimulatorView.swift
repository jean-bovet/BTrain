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

struct SimulatorView: View {
    let iconManager: LocomotiveIconManager
    @ObservedObject var simulator: MarklinCommandSimulator

    @State private var trainForward = true

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Central Station 3 Simulator").font(.title)
                Spacer()
                Text(simulator.enabled ? "Enabled" : "Disabled")
                    .bold()
                    .padding([.leading, .trailing])
                    .background(simulator.enabled ? .green : .gray)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            Divider()
            ScrollView {
                VStack {
                    ForEach(simulator.locomotives.sorted(), id: \.self) { train in
                        SimulatorTrainControlView(iconManager: iconManager, simulator: simulator, simLoc: train)
                    }
                }.disabled(!simulator.enabled)
            }
            HStack {
                VStack(spacing: 0) {
                    Text("Speed \(String(format: "%.1f", simulator.simulationSpeedFactor))x").font(.headline)
                    HStack {
                        Text("Slow")
                        Slider(
                            value: $simulator.simulationSpeedFactor,
                            in: 0.5 ... Double(4.0),
                            step: 0.5
                        ) {} onEditingChanged: { _ in
                        }
                        Text("Fast")
                    }
                }
                Divider().frame(maxHeight: 30)
                VStack(spacing: 0) {
                    Text("Turnouts").font(.headline)
                    HStack {
                        Text("Slow")
                        Slider(
                            value: $simulator.turnoutSpeedInverted,
                            in: 0 ... Double(MarklinCommandSimulator.MaxTurnoutSpeedValue)
                        ) {} onEditingChanged: { _ in
                        }
                        Text("Fast")
                    }
                }
            }
        }
        .padding()
    }
}

extension MarklinCommandSimulator {
    static let MaxTurnoutSpeedValue = 2.0

    var turnoutSpeedInverted: TimeInterval {
        get {
            MarklinCommandSimulator.MaxTurnoutSpeedValue - turnoutSpeed
        }
        set {
            turnoutSpeed = MarklinCommandSimulator.MaxTurnoutSpeedValue - newValue
        }
    }
}

struct SimulatorView_Previews: PreviewProvider {
    static let simulator: MarklinCommandSimulator = {
        let layout = LayoutLoop1().newLayout()
        layout.trains[0].block = layout.blocks[0]
        layout.trains[1].block = layout.blocks[1]
        return MarklinCommandSimulator(layout: layout, interface: MarklinInterface())
    }()

    static var previews: some View {
        SimulatorView(iconManager: LocomotiveIconManager(), simulator: simulator)
    }
}
