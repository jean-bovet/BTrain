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

enum ScriptDropLinePosition {
    case before
    case inside
    case after
}

struct ScriptDropLineView<Content: View>: View, DropDelegate {

    typealias OnMoveBlock = (_ sourceUUID: String, _ targetUUID: String, _ position: ScriptDropLinePosition) -> Void
    
    @State private var dropLine: ScriptDropLinePosition?

    let dragAllowed: Bool
    let dragInsideAllowed: Bool
    let commandID: String // command.id.uuidString
    let onMoveBlock: OnMoveBlock
    let content: Content
    
    init(commandID: String, dragAllowed: Bool = true, dragInsideAllowed: Bool = false, @ViewBuilder content: () -> Content, onMove: @escaping OnMoveBlock) {
        self.commandID = commandID
        self.dragAllowed = dragAllowed
        self.dragInsideAllowed = dragInsideAllowed
        self.content = content()
        self.onMoveBlock = onMove
    }

    var body: some View {
        content
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
            }).if(dragAllowed, transform: { view in
                view.onDrag {
                    NSItemProvider(object: commandID as NSString)
                }
            }).onDrop(of: [UTType.text], delegate: self)
    }
        
    func validateDrop(info: DropInfo) -> Bool {
        dragAllowed
    }
    
    func dropEntered(info: DropInfo) {
        updateDropLine(info: info)
    }
    
    func dropExited(info: DropInfo) {
        dropLine = .none
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if dragAllowed {
            updateDropLine(info: info)
            return DropProposal(operation: .move)
        } else {
            return DropProposal(operation: .forbidden)
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        let items = info.itemProviders(for: [UTType.text])
        if let item = items.first, let dropLine = dropLine {
            item.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { (data, error) in
                DispatchQueue.main.async {
                    if let data = data as? Data, let sourceUUID = String(data: data, encoding: .utf8), sourceUUID != commandID {
                        onMoveBlock(sourceUUID, commandID, dropLine)
                    }
                }
            }
            return true
        } else {
            return false
        }
    }
    
    private func updateDropLine(info: DropInfo) {
        if dragInsideAllowed {
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

}

struct ScriptDropLineView_Previews: PreviewProvider {
    static var previews: some View {
        ScriptDropLineView(commandID: "foo") {
            Text("This is a command")
        } onMove: { sourceUUID, targetUUID, position in
            print("Moving")
        }

    }
}
