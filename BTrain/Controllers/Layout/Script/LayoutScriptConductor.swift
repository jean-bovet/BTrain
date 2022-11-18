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

/// This class manages and executs layout scripts, which are scripts that orchestrate one or more
/// routes and trains together. There is only one layout script that can execute at one time in the layout.
final class LayoutScriptConductor {
    
    let layout: Layout
    
    /// The script being executed, nil if no script is executing
    weak var currentScript: LayoutScript?
    
    
    /// The layout controlling object
    weak var layoutControlling: LayoutControlling?
    
    /// Internal class that keeps track of the status of each command
    final class CurrentCommand: Hashable, Equatable {
        
        static func == (lhs: LayoutScriptConductor.CurrentCommand, rhs: LayoutScriptConductor.CurrentCommand) -> Bool {
            lhs.command == rhs.command
        }
        
        /// The command being tracked by this class
        let command: LayoutScriptCommand
        
        /// True if the command has started, false otherwise
        var started: Bool
        
        internal init(command: LayoutScriptCommand, started: Bool = false) {
            self.command = command
            self.started = started
        }
        
        func hash(into hasher: inout Hasher) {
          hasher.combine(command)
        }

    }
    
    /// Array of commands that are either in-progress or about to be started
    /// when the conditions are validated.
    private var commandQueue = Set<CurrentCommand>()
    
    internal init(layout: Layout) {
        self.layout = layout
    }
    
    /// Schedules the specified script for execution. The execution won't start immediately
    /// but at the next invocation of the ``tick()`` method below which is usually done
    /// by the ``LayoutController`` itself.
    /// - Parameter scriptId: the script to execute
    func schedule(_ scriptId: Identifier<LayoutScript>) {
        currentScript = layout.layoutScripts[scriptId]
        guard let currentScript = currentScript else {
            return
        }
        
        for command in currentScript.commands {
            schedule(command: command)
        }
    }
    
    /// Stops the execution of the specified script
    /// - Parameter scriptId: the script to stop which should be the same as the current script being executed
    func stop(_ scriptId: Identifier<LayoutScript>) throws {
        guard scriptId == currentScript?.id else {
            throw LayoutScriptError.cannotStopNonRunningScript(scriptId: scriptId)
        }
        
        for command in commandQueue {
            if command.started {
                if let train = layout.trains[command.command.trainId] {
                    layoutControlling?.stop(train: train)
                }
            }
        }
        
        commandQueue.removeAll()
        currentScript = nil
    }
    
    /// Invoke this method to process the command queue. Each time this method is invoked,
    /// commands are either started, stopped or removed from the queue depending on their state.
    func tick() throws {
        for command in commandQueue {
            try handle(command: command)
        }
        
        if commandQueue.isEmpty {
            currentScript = nil
        }
    }
    
    private func handle(command: CurrentCommand) throws {
        guard let trainId = command.command.trainId else {
            throw LayoutScriptError.trainMissingFromCommand(command: command.command.id)
        }
        
        guard let train = layout.trains[trainId] else {
            throw LayoutScriptError.trainNotFoundInLayout(trainId: trainId)
        }

        if train.scheduling == .unmanaged && command.started {
            // Command is considered done when the train has finished its route
            commandQueue.remove(command)
            
            // When a command is done, executes its children
            for child in command.command.children {
                try start(command: child)
            }
        } else if command.started == false {
            try start(command: command)
        }
    }
    
    private func schedule(command: LayoutScriptCommand) {
        let current = CurrentCommand(command: command)
        commandQueue.insert(current)
    }
    
    private func start(command: LayoutScriptCommand) throws {
        let current = CurrentCommand(command: command)
        commandQueue.insert(current)
        try start(command: current)
    }
    
    private func start(command: CurrentCommand) throws {
        guard let train = command.command.trainId else {
            throw LayoutScriptError.trainMissingFromCommand(command: command.command.id)
        }
        
        guard let script = command.command.routeScriptId else {
            throw LayoutScriptError.routeScriptMissingFromCommand(command: command.command.id)
        }
        
        try start(command: command, trainId: train, routeScriptId: script)
    }
    
    private func start(command: CurrentCommand, trainId: Identifier<Train>, routeScriptId: Identifier<RouteScript>) throws {
        guard let route = layout.routes.first(where: {$0.id.uuid == routeScriptId.uuid}) else {
            throw LayoutScriptError.routeNotFoundInLayout(routeId: routeScriptId.uuid)
        }
        
        guard let train = layout.trains[trainId] else {
            throw LayoutScriptError.trainNotFoundInLayout(trainId: trainId)
        }
        
        guard train.scheduling == .unmanaged else {
            return
        }
        
        command.started = true

        try layoutControlling?.start(routeID: route.id, trainID: train.id)
    }
    
}
