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

import Foundation
import Combine

/// This class manages and executs layout scripts, which are script that orchestrate one or more
/// routes and trains together.
final class LayoutScriptConductor {
    
    let layout: Layout
    
    weak var currentScript: LayoutScript?
    weak var layoutControlling: LayoutControlling?
            
    final class CurrentCommand: Hashable, Equatable {
        
        static func == (lhs: LayoutScriptConductor.CurrentCommand, rhs: LayoutScriptConductor.CurrentCommand) -> Bool {
            lhs.command == rhs.command
        }
        
        let command: LayoutScriptCommand
        var started: Bool
        
        internal init(command: LayoutScriptCommand, started: Bool = false) {
            self.command = command
            self.started = started
        }
        
        func hash(into hasher: inout Hasher) {
          hasher.combine(command)
        }

    }
    
    private var runningCommands = Set<CurrentCommand>()
    
    internal init(layout: Layout) {
        self.layout = layout
    }

    func schedule(_ scriptId: Identifier<LayoutScript>) {
        currentScript = layout.layoutScripts[scriptId]
        guard let currentScript = currentScript else {
            return
        }
        
        for command in currentScript.commands {
            schedule(command: command)
        }
    }
    
    func stop(_ scriptId: Identifier<LayoutScript>) {
        guard scriptId == currentScript?.id else {
            // TODO: throw
            return
        }
        
        for command in runningCommands {
            if command.started {
                if let train = layout.trains[command.command.trainId] {
                    layoutControlling?.stop(train: train)
                }
            }
        }
        
        currentScript = nil
    }
    
    func tick() throws {
        for command in runningCommands {
            try handle(command: command)
        }
        
        if runningCommands.isEmpty {
            currentScript = nil
        }
    }
    
    private func handle(command: CurrentCommand) throws {
        guard let train = layout.trains[command.command.trainId] else {
            // TODO: throw
            return
        }

        if train.scheduling == .unmanaged && command.started {
            // Command is considered done when the train has finished its route
            runningCommands.remove(command)
            for child in command.command.children {
                try start(command: child)
            }
        } else if command.started == false {
            try start(command: command)
        }
    }
    
    private func schedule(command: LayoutScriptCommand) {
        let current = CurrentCommand(command: command)
        runningCommands.insert(current)
    }
    
    private func start(command: LayoutScriptCommand) throws {
        let current = CurrentCommand(command: command)
        runningCommands.insert(current)
        try start(command: current)
    }
    
    private func start(command: CurrentCommand) throws {
        guard let train = command.command.trainId else {
            // TODO: throw
            return
        }
        
        guard let script = command.command.routeScriptId else {
            // TODO: throw
            return
        }
        
        command.started = true
        try start(trainId: train, routeScriptId: script)
    }
    
    private func start(trainId: Identifier<Train>?, routeScriptId: Identifier<RouteScript>?) throws {
        guard let route = layout.routes.first(where: {$0.id.uuid == routeScriptId?.uuid}) else {
            // TODO: throw
            return
        }
        
        guard let train = layout.trains[trainId] else {
            // TODO: throw
            return
        }
        
        try layoutControlling?.start(routeID: route.id, trainID: train.id)
    }
    
}
