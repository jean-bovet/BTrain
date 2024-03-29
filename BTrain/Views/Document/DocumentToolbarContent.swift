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

// This structure defines the window toolbar content
struct DocumentToolbarContent: ToolbarContent {
    @ObservedObject var document: LayoutDocument

    @Binding var connectAlertShowing: Bool

    var body: some ToolbarContent {
        ToolbarItemGroup {
            ConnectCommandsView(document: document, connectAlertShowing: $connectAlertShowing)
            Spacer()
        }

        ToolbarItemGroup {
            DeveloperCommandsView(document: document)

            SwitchboardSettingsButton(document: document)
            SwitchboardEditButton(document: document, state: document.switchboard.state)
        }
    }
}

// Note: in order for the button to change state depending on a property change
// in the document, you have to put each control inside a separate SwiftUI view,
// otherwise the command state is never updated.
struct ConnectCommandsView: View {
    @ObservedObject var document: LayoutDocument
    @Binding var connectAlertShowing: Bool

    var body: some View {
        if document.connected {
            Button("Disconnect") {
                document.disconnect {}
            }
            .foregroundColor(.red)

            Spacer()

            PowerStateIndicationView(document: document, simulator: document.simulator)

            Spacer()

            if document.power {
                Button("Stop") {
                    document.disable {}
                }
                .help("Disable Power")
            } else {
                Button("Go") {
                    document.enable {}
                }
                .help("Enable Power")
            }
        } else {
            Button("Connect") {
                self.connectAlertShowing.toggle()
            }
            .foregroundColor(.green)
        }
    }
}

struct PowerStateIndicationView: View {
    @ObservedObject var document: LayoutDocument
    @ObservedObject var simulator: MarklinCommandSimulator

    var text: String {
        var t = ""
        if document.power {
            t += "􀋦 Power ON"
        } else {
            t += "􀋪 Power OFF"
        }
        if simulator.started {
            t += " [Simulator]"
        }
        return t
    }

    var body: some View {
        Text(text)
            .bold()
            .padding([.all], 5)
            .background(document.power ? .green : .red)
            .foregroundColor(.white)
            .clipShape(Capsule())
        Spacer()
    }
}

struct DeveloperCommandsView: View {
    @ObservedObject var document: LayoutDocument
    @AppStorage("switchboardWhiteBackground") var switchboardWhiteBackground = false

    var body: some View {
        if document.showDebugModeControls {
            Menu("􀤊") {
                Button("Repair Layout") {
                    LayoutDiagnostic(layout: document.layout).repair()
                }

                Divider()

                Toggle("White Background", isOn: $switchboardWhiteBackground)
            }
        }
    }
}

struct SwitchboardEditButton: View {
    @ObservedObject var document: LayoutDocument
    @ObservedObject var state: SwitchBoard.State

    var body: some View {
        if !document.connected {
            Button("􀈊") {
                state.editing.toggle()
                if state.editing {
                    document.switchboard.startEditing()
                } else {
                    document.switchboard.doneEditing()
                }
            }.help("Edit Switchboard")
        }
    }
}

struct SwitchboardSettingsButton: View {
    @ObservedObject var document: LayoutDocument

    var body: some View {
        Button("􀋭") {
            document.showSwitchboardViewSettings.toggle()
        }.help("Show/hide Switchboard View Settings")
    }
}
