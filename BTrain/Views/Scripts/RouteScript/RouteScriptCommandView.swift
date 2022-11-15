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

struct RouteScriptCommandView: View {

    let layout: Layout
    @ObservedObject var script: RouteScript
    @Binding var command: RouteScriptCommand
    @Binding var commandErrorIds: [String]
    
    var body: some View {
        HStack {
            if command.action != .start {
                Text("􀌇")
            }
            if commandErrorIds.contains(command.id.uuidString) {
                Text("􀇿")
                    .foregroundColor(.red)
            }
            
            if command.action != .start {
                Picker("Command", selection: $command.action) {
                    ForEach(RouteScriptCommand.Action.allCases.filter({$0 != .start}), id: \.self) {
                        Text($0.rawValue).tag($0 as RouteScriptCommand.Action?)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            
            switch command.action {
            case .start:
                Text("Start in")
                BlockPicker(layout: layout, blockId: $command.blockId)
                    .fixedSize()
                Text("with direction")
                    .fixedSize()
                DirectionPicker(direction: $command.direction)

            case .move:
                Text("to")
                Picker("DestinationType", selection: $command.destinationType) {
                    ForEach(RouteScriptCommand.MoveDestinationType.allCases, id: \.self) {
                        Text($0.rawValue).tag($0 as RouteScriptCommand.MoveDestinationType)
                    }
                }
                .labelsHidden()
                .fixedSize()

                switch command.destinationType {
                case .block:
                    BlockPicker(layout: layout, blockId: $command.blockId)
                        .fixedSize()
                    Text("with direction")
                        .fixedSize()
                    DirectionPicker(direction: $command.direction)
                case .station:
                    StationPicker(layout: layout, stationId: $command.stationId)
                        .fixedSize()
                }
                
                if layout.block(for: command.blockId)?.category == .station {
                    Stepper("and wait \(command.waitDuration) seconds", value: $command.waitDuration, in: 0...100, step: 10)
                        .fixedSize()
                }
            case .loop:
                Stepper("\(command.repeatCount) times", value: $command.repeatCount, in: 1...10)
                    .fixedSize()
            }
            
            Button("􀁌") {
                script.commands.insert(source: RouteScriptCommand(action: .move), target: command, position: .after)
            }.buttonStyle(.borderless)
            
            if command.action != .start {
                Button("􀁎") {
                    script.commands.remove(source: command)
                }.buttonStyle(.borderless)
            }
        }
    }
}

struct ScriptCommandView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutComplex().newLayout())
    static let script = RouteScript()
    
    static let start = RouteScriptCommand(action: .start)
    
    static let moveToFreeBlock = {
        var cmd = RouteScriptCommand(action: .move)
        cmd.blockId = doc.layout.blocks.first(where: {$0.category == .free})!.id
        cmd.direction = .next
        return cmd
    }()
    
    static let moveToStationBlock = {
        var cmd = RouteScriptCommand(action: .move)
        cmd.blockId = doc.layout.blocks.first(where: {$0.category == .station})!.id
        cmd.direction = .next
        return cmd
    }()

    static let loop = {
        var cmd = RouteScriptCommand(action: .loop)
        cmd.repeatCount = 2
        cmd.children = [moveToFreeBlock, moveToStationBlock]
        return cmd
    }()

    static let commands = [start, moveToFreeBlock, moveToStationBlock, loop]
    
    static var previews: some View {
        VStack(alignment: .leading) {
            ForEach(commands, id:\.self) { command in
                RouteScriptCommandView(layout: doc.layout, script: script, command: .constant(command), commandErrorIds: .constant([]))
                    .fixedSize()
            }
        }
    }
}
