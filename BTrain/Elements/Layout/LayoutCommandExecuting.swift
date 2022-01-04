//
//  LayoutCommandExecuting.swift
//  BTrain
//
//  Created by Jean Bovet on 1/3/22.
//

import Foundation

// A protocol that the layout uses to push information to the Digital Control System
protocol LayoutCommandExecuting {
    // Indicates that the train speed should be sent to the Digital Control System
    func trainSpeedChanged(train: Train)
}

extension Layout: LayoutCommandExecuting {
    func trainSpeedChanged(train: Train) {
        BTLogger.debug("Train \(train.name) changed speed to \(train.speed)", self, train)
        interface?.execute(command: .speed(address: train.address, speed: train.speed))
    }
}

