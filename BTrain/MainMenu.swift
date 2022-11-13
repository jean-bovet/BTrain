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

    var body: some Commands {
        CommandGroup(after: CommandGroupPlacement.sidebar) {
            Group {
                CommandSelectedView(viewType: .overview, label: "Switchboard").keyboardShortcut("0", modifiers: [.command])
                CommandSelectedView(viewType: .scripts, label: "Scripts").keyboardShortcut("1", modifiers: [.command])
                CommandSelectedView(viewType: .routes, label: "Routes").keyboardShortcut("2", modifiers: [.command])
                CommandSelectedView(viewType: .trains, label: "Trains").keyboardShortcut("3", modifiers: [.command])
                CommandSelectedView(viewType: .locomotives, label: "Locomotives").keyboardShortcut("4", modifiers: [.command])
                CommandSelectedView(viewType: .stations, label: "Stations").keyboardShortcut("5", modifiers: [.command])
                CommandSelectedView(viewType: .blocks, label: "Blocks").keyboardShortcut("6", modifiers: [.command])
                CommandSelectedView(viewType: .turnouts, label: "Turnouts").keyboardShortcut("7", modifiers: [.command])
                CommandSelectedView(viewType: .feedback, label: "Feedback").keyboardShortcut("8", modifiers: [.command])
            }
            Divider()
            CommandSelectedView(viewType: .cs3, label: "Central Station 3 Debugger")
            Divider()
        }
    }
}
