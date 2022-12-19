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

struct MenuCommands: Commands {
    @FocusedValue(\.document) var document
    @FocusedBinding(\.power) var power

    var body: some Commands {
        CommandGroup(after: CommandGroupPlacement.sidebar) {
            Group {
                ForEach(LayoutDocument.DisplaySheetType.allCases.filter { !$0.debugOnly }, id: \.self) { type in
                    if type == .trains {
                        Divider()
                    }
                    CommandSelectedView(viewType: type)
                        .disabled(power == true)
                }
                if document?.showDebugModeControls == true {
                    Divider()
                    ForEach(LayoutDocument.DisplaySheetType.allCases.filter(\.debugOnly), id: \.self) { type in
                        CommandSelectedView(viewType: type)
                    }
                }
                Divider()

                Button("Diagnostic") {
                    document?.triggerLayoutDiagnostic.toggle()
                }.keyboardShortcut("d", modifiers: [.command])

                Divider()
            }
        }
    }
}

struct CommandSelectedView: View {
    @FocusedValue(\.document) var document

    let viewType: LayoutDocument.DisplaySheetType

    var body: some View {
        Button(viewType.label) {
            document?.displaySheetType = viewType
        }
        .if(viewType.shortcut != nil) {
            $0.keyboardShortcut(viewType.shortcut!, modifiers: [.command])
        }
    }
}

struct DocumentFocusedValueKey: FocusedValueKey {
    typealias Value = LayoutDocument
}

struct DocumentPowerFocusedValueKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var document: DocumentFocusedValueKey.Value? {
        get {
            self[DocumentFocusedValueKey.self]
        }

        set {
            self[DocumentFocusedValueKey.self] = newValue
        }
    }

    var power: DocumentPowerFocusedValueKey.Value? {
        get {
            self[DocumentPowerFocusedValueKey.self]
        }

        set {
            self[DocumentPowerFocusedValueKey.self] = newValue
        }
    }
}
