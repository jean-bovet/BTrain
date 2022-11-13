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

struct ScriptView: View {
    
    let layout: Layout
    @ObservedObject var script: Script
    
    var body: some View {
        VStack {
            List {
                ForEach($script.commands, id: \.self) { command in
                    ScriptLineView(layout: layout, commands: $script.commands, command: command)
                    if let children = command.children {
                        ForEach(children, id: \.self) { command in
                            HStack {
                                Spacer().fixedSpace()
                                ScriptLineView(layout: layout, commands: $script.commands, command: command)
                            }
                        }
                    }
                }
            }

            HStack {
                Text("\(script.commands.count) commands")
                Spacer()
                Button("+") {
                    script.commands.append(ScriptCommand(action: .move))
                }
                Button("-") {
                    
                }
            }.padding()
        }
    }
    
}

struct ScriptView_Previews: PreviewProvider {
        
    static let layout = {
        let layout = Layout()
        let s = Script(name: "Boucle")
        s.commands.append(ScriptCommand(action: .move))
        s.commands.append(ScriptCommand(action: .wait))
        var loop = ScriptCommand(action: .loop)
        loop.repeatCount = 2
        loop.children.append(ScriptCommand(action: .move))
        loop.children.append(ScriptCommand(action: .move))
        s.commands.append(loop)
        layout.scriptMap[s.id] = s
        return layout
    }()

    static var previews: some View {
        ScriptView(layout: layout, script: layout.scripts[0])
    }
}
