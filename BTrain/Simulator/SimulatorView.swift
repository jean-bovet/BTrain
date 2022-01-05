//
//  SimulatorView.swift
//  BTrain
//
//  Created by Jean Bovet on 1/3/22.
//

import SwiftUI

struct SimulatorView: View {
    
    @Environment(\.colorScheme) var colorScheme

    @ObservedObject var  simulator: MarklinCommandSimulator
    
    @State private var trainForward = true
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Central Station 3 Simulator").font(.title)
                Spacer()
                Text(simulator.enabled ? "Enabled" : "Disabled")
                    .bold()
                    .padding([.leading, .trailing])
                    .background(simulator.enabled ? .green : .red)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            VStack {
                ForEach(simulator.trains, id:\.self) { train in
                    HStack {
                        Text(train.train.name)
                        SimulatorTrainControlView(simulator: simulator, train: train)
                    }
                }
            }.disabled(!simulator.enabled)
        }
        .padding()
        .background(colorScheme == .dark ? .indigo.opacity(0.5) : .yellow.opacity(0.5))
    }
}

struct SimulatorView_Previews: PreviewProvider {
    
    static let simulator: MarklinCommandSimulator = {
        let layout = LayoutACreator().newLayout()
        layout.trains[0].blockId = layout.blockIds[0]
        layout.trains[1].blockId = layout.blockIds[1]
        return MarklinCommandSimulator(layout: layout)
    }()

    static var previews: some View {
        ForEach(ColorScheme.allCases, id: \.self) {
            SimulatorView(simulator: simulator)
                .preferredColorScheme($0)
        }
    }
}
