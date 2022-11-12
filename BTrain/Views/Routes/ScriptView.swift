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

struct ScriptCommandLineView: View {

    @Binding var command: ScriptCommand
    
//    @State private var selectedCmd: ScriptAction?
        
    var body: some View {
        HStack {
            Picker("Command", selection: $command.action) {
                ForEach(ScriptAction.allCases, id: \.self) {
                    Text($0.rawValue).tag($0 as ScriptAction?)
                }
            }.labelsHidden()
        }
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
                ScriptCommandLineView(command: command)
                if let children = command.children {
                    ForEach(children, id: \.self) { command in
                        HStack {
                            Spacer().fixedSpace()
                            ScriptCommandLineView(command: command)
                        }
                    }
                }
            }.onMove(perform: move)
        }
    }
    
    func move(from source: IndexSet, to destination: Int) {
        commands.move(fromOffsets: source, toOffset: destination)
    }

}

struct ScriptView_Previews: PreviewProvider {
        
    static var previews: some View {
        ScriptView()
    }
}
