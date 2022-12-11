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

struct RouteScriptLineView: View {
    let doc: LayoutDocument
    let layout: Layout

    @ObservedObject var script: RouteScript
    @Binding var command: RouteScriptCommand
    @Binding var commandErrorIds: [String]

    var body: some View {
        DragAndDropLineView(lineUUID: command.id.uuidString, dragAllowed: command.action.draggable, dragInsideAllowed: command.action == .loop) {
            RouteScriptCommandView(doc: doc, layout: layout, script: script, command: $command, commandErrorIds: $commandErrorIds)
        } onMove: { sourceUUID, targetUUID, position in
            guard let sourceCommand = script.commands.commandWith(uuid: sourceUUID) else {
                return
            }
            guard let targetCommand = script.commands.commandWith(uuid: targetUUID) else {
                return
            }

            script.commands.remove(source: sourceCommand)
            switch position {
            case .before:
                script.commands.insert(source: sourceCommand, before: targetCommand)
            case .inside:
                script.commands.insert(source: sourceCommand, inside: targetCommand)
            case .after:
                script.commands.insert(source: sourceCommand, after: targetCommand)
            }
        }
    }
}

struct ScriptLineView_Previews: PreviewProvider {
    static let doc = LayoutDocument(layout: LayoutComplex().newLayout())
    static let command = RouteScriptCommand(action: .move)

    static var previews: some View {
        VStack(alignment: .leading) {
            RouteScriptLineView(doc: doc, layout: doc.layout, script: RouteScript(), command: .constant(command), commandErrorIds: .constant([]))
            RouteScriptLineView(doc: doc, layout: doc.layout, script: RouteScript(), command: .constant(command), commandErrorIds: .constant([command.id.uuidString]))
        }
    }
}
