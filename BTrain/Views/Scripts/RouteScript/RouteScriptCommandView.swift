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
    let doc: LayoutDocument
    let layout: Layout
    @ObservedObject var script: RouteScript
    @Binding var command: RouteScriptCommand
    @Binding var commandErrorIds: [String]
    @State private var showFunctionsSheet = false
    
    var functions: some View {
        HStack {
            if command.functions.isEmpty {
                Button("Add…") {
                    showFunctionsSheet.toggle()
                }
            } else {
                ForEach(command.functions, id: \.self) { function in
                    Group {
                        if let image = doc.locomotiveFunctionsCatalog.image(for: function.type, state: function.enabled) {
                            Image(nsImage: image)
                                .resizable()
                                .renderingMode(.template)
                                .frame(width: 20, height: 20)
                        } else {
                            Text("f\(function.type)")
                        }
                    }
                    .if(function.enabled, transform: { $0.foregroundColor(.yellow)})
                        .help(doc.locomotiveFunctionsCatalog.name(for: function.type) ?? "")
                }
                Button("Edit…") {
                    showFunctionsSheet.toggle()
                }
            }
        }
    }
    
    var body: some View {
        HStack {
            if command.action.draggable {
                Text("􀌃")
            }
            if commandErrorIds.contains(command.id.uuidString) {
                Text("􀇿")
                    .foregroundColor(.red)
            }

            if command.action.mutable {
                Picker("Command", selection: $command.action) {
                    ForEach(RouteScriptCommand.Action.allCases.filter { $0 != .start }, id: \.self) {
                        Text($0.rawValue).tag($0 as RouteScriptCommand.Action?)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            switch command.action {
            case .start:
                Text("Start in")
                    .fixedSize()
                BlockPicker(layout: layout, blockId: $command.blockId)
                    .labelsHidden()
                    .fixedSize()
                Text("with direction")
                    .fixedSize()
                DirectionPicker(direction: $command.direction)
                    .labelsHidden()

                Text("and")
                
                functions
                
            case .stop:
                Text("Completion:")
                    .fixedSize()

                functions

            case .move:
                Text("to")
                    .fixedSize()
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
                        .labelsHidden()
                        .fixedSize()
                    Text("with direction")
                        .fixedSize()
                    DirectionPicker(direction: $command.direction)
                        .labelsHidden()
                case .station:
                    StationPicker(layout: layout, stationId: $command.stationId)
                        .fixedSize()
                }

                if layout.blocks[command.blockId]?.category == .station {
                    Stepper("and wait \(command.waitDuration) seconds", value: $command.waitDuration, in: 0 ... 100, step: 10)
                        .fixedSize()
                }
                
                Text("and")
                
                functions

            case .loop:
                Stepper("\(command.repeatCount) times", value: $command.repeatCount, in: 1 ... 10)
                    .fixedSize()
            }

            if command.action != .stop {
                Button("􀁌") {
                    script.commands.insert(source: RouteScriptCommand(action: .move), after: command)
                }.buttonStyle(.borderless)
            }

            if command.action.deletable {
                Button("􀁎") {
                    script.commands.remove(source: command)
                }.buttonStyle(.borderless)
            }
        }.sheet(isPresented: $showFunctionsSheet) {
            RouteScriptFunctionsView(catalog: doc.locomotiveFunctionsCatalog, cmd: $command)
                .padding()
                .frame(width: 600, height: 300)
        }
    }
}

struct ScriptCommandView_Previews: PreviewProvider {
    static let doc = LayoutDocument(layout: LayoutComplex().newLayout())
    static let script = RouteScript()

    static let start = RouteScriptCommand(action: .start)
    static let stop = RouteScriptCommand(action: .stop)

    static let moveToFreeBlock = {
        var cmd = RouteScriptCommand(action: .move)
        cmd.blockId = doc.layout.blocks.elements.first(where: { $0.category == .free })!.id
        cmd.direction = .next
        return cmd
    }()

    static let moveToStationBlock = {
        var cmd = RouteScriptCommand(action: .move)
        cmd.blockId = doc.layout.blocks.elements.first(where: { $0.category == .station })!.id
        cmd.direction = .next
        cmd.functions = [.init(type: 0, enabled: true), .init(type: 2, enabled: false)]
        return cmd
    }()

    static let loop = {
        var cmd = RouteScriptCommand(action: .loop)
        cmd.repeatCount = 2
        cmd.children = [moveToFreeBlock, moveToStationBlock]
        return cmd
    }()

    static let commands = [start, moveToFreeBlock, moveToStationBlock, loop, stop]

    static var previews: some View {
        VStack(alignment: .leading) {
            ForEach(commands, id: \.self) { command in
                RouteScriptCommandView(doc: doc, layout: doc.layout, script: script, command: .constant(command), commandErrorIds: .constant([]))
                    .fixedSize()
            }
        }
    }
}
