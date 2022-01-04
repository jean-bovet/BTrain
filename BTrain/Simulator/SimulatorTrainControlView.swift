//
//  SimulatorTrainControlView.swift
//  BTrain
//
//  Created by Jean Bovet on 1/3/22.
//

import SwiftUI

struct SimulatorTrainControlView: View {
    
    @ObservedObject var train: SimulatorTrain
    
    var body: some View {
        HStack {
            Button {
                train.directionForward.toggle()
            } label: {
                if train.directionForward {
                    Image(systemName: "arrowtriangle.right.fill")
                } else {
                    Image(systemName: "arrowtriangle.left.fill")
                }
            }.buttonStyle(.borderless)
            
            Slider(
                value: $train.speed,
                in: 0...100
            ) {
            } onEditingChanged: { editing in
                // No-op
            }
            
            Text("\(Int(train.speed)) km/h")
        }
    }
}

struct SimulatorTrainControlView_Previews: PreviewProvider {

    static let layout = LayoutACreator().newLayout()
    
    static var previews: some View {
        SimulatorTrainControlView(train: .init(train: layout.trains[0]))
    }
}
