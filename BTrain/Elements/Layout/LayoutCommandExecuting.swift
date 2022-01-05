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
    func trainDirectionChanged(train: Train)
    func trainSpeedChanged(train: Train)
}

extension Layout: LayoutCommandExecuting {
    
    func trainDirectionChanged(train: Train) {
        BTLogger.debug("Train \(train.name) changed direction to \(train.directionForward ? "forward" : "backward" )", self, train)
        let command: Command
        if train.directionForward {
            command = .direction(address: train.address, direction: .forward)
        } else {
            command = .direction(address: train.address, direction: .backward)
        }
        interface?.execute(command: command)
    }
    
    func trainSpeedChanged(train: Train) {
        BTLogger.debug("Train \(train.name) changed speed to \(train.speed)", self, train)
        interface?.execute(command: .speed(address: train.address, speed: train.speed))
    }
}

