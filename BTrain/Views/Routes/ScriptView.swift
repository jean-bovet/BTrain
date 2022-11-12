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
import UniformTypeIdentifiers

enum ScriptAction: String, CaseIterable {
    case move = "Move"
    case loop = "Repeat"
    case wait = "Wait"
}

struct ScriptCommand: Identifiable, Hashable {
    let id = UUID()
    var action: ScriptAction = .move
    var children = [ScriptCommand]()
}

private enum DropPosition {
    case before
    case after
}

struct ScriptCommandLineView: View, DropDelegate {
    
    @Binding var commands: [ScriptCommand]
    @Binding var command: ScriptCommand
    
    @State private var dropLine: DropPosition?
    
    var body: some View {
        HStack {
            Text("􀌇")
            Picker("Command", selection: $command.action) {
                ForEach(ScriptAction.allCases, id: \.self) {
                    Text($0.rawValue).tag($0 as ScriptAction?)
                }
            }
            .labelsHidden()
            .fixedSize()
        }.if(dropLine != nil, transform: { view in
            view.overlay(
                Rectangle()
                    .frame(height: 4)
                    .foregroundColor(.blue),
                alignment: dropLine! == .after ? .bottom : .top
            )
        }).onDrag {
            return NSItemProvider(object: command.id.uuidString as NSString)
        }.onDrop(of: [UTType.text], delegate: self)
    }
        
    func dropEntered(info: DropInfo) {
        updateDropLine(info: info)
    }
    
    func dropExited(info: DropInfo) {
        dropLine = .none
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateDropLine(info: info)
        return DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        let items = info.itemProviders(for: [UTType.text])
        if let item = items.first, let dropLine = dropLine {
            item.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { (data, error) in
                if let data = data as? Data, let sourceUUID = String(data: data, encoding: .utf8) {
                    move(sourceUUID: sourceUUID, targetUUID: command.id.uuidString, position: dropLine)
                }
            }
            return true
        } else {
            return false
        }
    }
    
    func updateDropLine(info: DropInfo) {
        if info.location.y <= 10 {
            dropLine = .before
        } else {
            dropLine = .after
        }
    }

    fileprivate func move(sourceUUID: String, targetUUID: String, position: DropPosition) {
        guard let sourceCommand = commands.commandWith(uuid: sourceUUID) else {
            return
        }
        guard let targetCommand = commands.commandWith(uuid: targetUUID) else {
            return
        }
        
        commands.remove(source: sourceCommand)
        commands.insert(source: sourceCommand, target: targetCommand, position: position)
    }
}

extension Array where Element == ScriptCommand {
    
    func commandWith(uuid: String) -> ScriptCommand? {
        for command in self {
            if command.id.uuidString == uuid {
                return command
            }
            if let command = command.children.commandWith(uuid: uuid) {
                return command
            }
        }
        return nil
    }
    
    mutating func remove(source: ScriptCommand) {
        for (index, command) in enumerated() {
            if command.id == source.id {
                remove(at: index)
                return
            }
            self[index].children.remove(source: source)
        }
    }
    
    @discardableResult
    mutating fileprivate func insert(source: ScriptCommand, target: ScriptCommand, position: DropPosition) -> Bool {
        for (index, command) in enumerated() {
            if command.id == target.id {
                switch position {
                case .before:
                    insert(source, at: index)
                case .after:
                    insert(source, at: index + 1)
                }
                return true
            }
            if self[index].children.insert(source: source, target: target, position: position) {
                return true
            }
        }
        return false
    }
}

struct ScriptView: View {
    
    @State private var commands = [
        ScriptCommand(action: .move),
        ScriptCommand(action: .loop, children: [
            ScriptCommand(action: .move),
            ScriptCommand(action: .wait),
        ])
    ]
    
    var body: some View {
        List {
            ForEach($commands, id: \.self) { command in
                ScriptCommandLineView(commands: $commands, command: command)
                if let children = command.children {
                    ForEach(children, id: \.self) { command in
                        HStack {
                            Spacer().fixedSpace()
                            ScriptCommandLineView(commands: $commands, command: command)
                        }
                    }
                }
            }
        }
    }
    
}

struct ScriptView_Previews: PreviewProvider {
        
    static var previews: some View {
        ScriptView()
    }
}
