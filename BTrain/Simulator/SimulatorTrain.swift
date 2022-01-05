//
//  SimulatorTrain.swift
//  BTrain
//
//  Created by Jean Bovet on 1/4/22.
//

import Foundation

final class SimulatorTrain: ObservableObject, Element {
    let id: Identifier<Train>
    let train: Train
    
    @Published var directionForward = true
    @Published var speed: UInt16 = 0
        
    init(train: Train) {
        self.id = train.id
        self.train = train
        self.directionForward = train.directionForward
        self.speed = train.speed
    }
}
    
