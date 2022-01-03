//
//  SimulatorView.swift
//  BTrain
//
//  Created by Jean Bovet on 1/3/22.
//

import SwiftUI

struct SimulatorView: View {
    
    @ObservedObject var  simulator: MarklinCommandSimulator
    
    @State private var trainForward = true
    @State private var trainId: Identifier<Train>?
    
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
            HStack {
                Picker("Locomotive:", selection: $trainId) {
                    ForEach(simulator.trains, id:\.self) { train in
                        Text(train.name).tag(train.id as Identifier<Train>?)
                    }
                }
                
                if let train = simulator.trains.first(where: { $0.id == trainId }) {
                    SimulatorTrainControlView(train: train)
                }
            }.disabled(!simulator.enabled)
        }
        .padding()
        .background(.yellow)
    }
}

struct SimulatorView_Previews: PreviewProvider {
    
    static let simulator = MarklinCommandSimulator(layout: LayoutACreator().newLayout())

    static var previews: some View {
        SimulatorView(simulator: simulator)
    }
}
