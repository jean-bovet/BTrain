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

struct RouteScriptFunctionsView: View {
    let catalog: LocomotiveFunctionsCatalog
    @Binding var cmd: RouteScriptCommand
    @State private var editedCmd = RouteScriptCommand(action: .move)

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            HStack {
                Text("Functions to execute:")
                Spacer()
            }
            if editedCmd.functions.isEmpty {
                Spacer()
                Button("Click 􀁌 To Add a Function") {
                    addFunction()
                }
                .buttonStyle(.borderless)
                .padding()
                Spacer()
            } else {
                List {
                    ForEach($editedCmd.functions, id: \.self) { function in
                        HStack {
                            RouteScriptFunctionLineView(catalog: catalog, function: function)

                            Spacer()

                            Button("􀁌") {
                                addFunction()
                            }.buttonStyle(.borderless)

                            Button("􀁎") {
                                removeFunction(function: function.wrappedValue)
                            }.buttonStyle(.borderless)
                        }
                    }
                }
            }
            Divider()
            HStack {
                Spacer()

                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer().fixedSpace()

                Button("OK") {
                    cmd = editedCmd
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }.padding()
        }.onAppear {
            editedCmd = cmd
        }
    }

    func addFunction() {
        editedCmd.functions.append(.init(type: 1))
    }

    func removeFunction(function: RouteItemFunction) {
        editedCmd.functions.removeAll(where: { $0.id == function.id })
    }
}

struct RouteScriptFunctionsView_Previews: PreviewProvider {
    static let cmd = {
        var command = RouteScriptCommand(action: .move)
        command.functions = [.init(type: 0)]
        return command
    }()

    static var previews: some View {
        Group {
            RouteScriptFunctionsView(catalog: LocomotiveFunctionsCatalog(interface: MarklinInterface()), cmd: .constant(RouteScriptCommand(action: .move)))
        }.previewDisplayName("Empty")
        Group {
            RouteScriptFunctionsView(catalog: LocomotiveFunctionsCatalog(interface: MarklinInterface()), cmd: .constant(cmd))
        }.previewDisplayName("Functions")
    }
}
