//
//  LayoutCommandExecuting.swift
//  BTrain
//
//  Created by Jean Bovet on 1/3/22.
//

import Foundation

// A protocol that the layout uses to push information to the Digital Control System
protocol LayoutCommandExecuting {
    func turnoutStateChanged(turnout: Turnout)
    func trainDirectionChanged(train: Train)
    func trainSpeedChanged(train: Train)
}

extension Layout: LayoutCommandExecuting {
    
    func turnoutStateChanged(turnout: Turnout) {
        BTLogger.debug("Turnout \(turnout) state changed to \(turnout.state)")
        
        guard let interface = interface else {
            return
        }
        
        let commands = turnout.stateCommands(power: 0x1)
        commands.forEach { interface.execute(command: $0 )}

        // Turn-off the turnout power after 250ms (activation time)
        let idleCommands = turnout.stateCommands(power: 0x0)
        Timer.scheduledTimer(withTimeInterval: 0.250, repeats: false) { timer in
            idleCommands.forEach { interface.execute(command: $0 )}
        }
    }

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

