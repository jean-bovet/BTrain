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

struct ScriptLineView: View, DropDelegate {
    
    enum DropPosition {
        case before
        case inside
        case after
    }

    let layout: Layout
    
    @ObservedObject var script: Script
    @Binding var command: ScriptCommand
    @Binding var commandErrorIds: [String]

    @State private var dropLine: DropPosition?
    
    var body: some View {
        ScriptCommandView(layout: layout, script: script, command: $command, commandErrorIds: $commandErrorIds)
            .if(dropLine == .inside, transform: { view in
                view.overlay(
                    Rectangle()
                        .foregroundColor(.blue).opacity(0.5),
                    alignment: .center
                )
            }).if(dropLine == .before || dropLine == .after, transform: { view in
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
                DispatchQueue.main.async {
                    if let data = data as? Data, let sourceUUID = String(data: data, encoding: .utf8), sourceUUID != command.id.uuidString {
                        move(sourceUUID: sourceUUID, targetUUID: command.id.uuidString, position: dropLine)
                    }
                }
            }
            return true
        } else {
            return false
        }
    }
    
    func updateDropLine(info: DropInfo) {
        if command.action == .loop {
            if info.location.y <= 5 {
                dropLine = .before
            } else if info.location.y >= 15 {
                dropLine = .after
            } else {
                dropLine = .inside
            }
        } else {
            if info.location.y <= 10 {
                dropLine = .before
            } else {
                dropLine = .after
            }
        }
    }

    fileprivate func move(sourceUUID: String, targetUUID: String, position: DropPosition) {
        guard let sourceCommand = script.commands.commandWith(uuid: sourceUUID) else {
            return
        }
        guard let targetCommand = script.commands.commandWith(uuid: targetUUID) else {
            return
        }
        
        script.commands.remove(source: sourceCommand)
        script.commands.insert(source: sourceCommand, target: targetCommand, position: position)
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
    mutating func insert(source: ScriptCommand, target: ScriptCommand, position: ScriptLineView.DropPosition) -> Bool {
        for (index, command) in enumerated() {
            if command.id == target.id {
                switch position {
                case .before:
                    insert(source, at: index)
                case .inside:
                    self[index].children.append(source)
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

struct ScriptLineView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutComplex().newLayout())
    static let command = ScriptCommand(action: .move)
    
    static var previews: some View {
        VStack(alignment: .leading) {
            ScriptLineView(layout: doc.layout, script: Script(), command: .constant(command), commandErrorIds: .constant([]))
            ScriptLineView(layout: doc.layout, script: Script(), command: .constant(command), commandErrorIds: .constant([command.id.uuidString]))
        }
    }
}
