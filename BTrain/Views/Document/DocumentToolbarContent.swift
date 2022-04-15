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
            
            DiagnosticsIndicationView(diagnostics: document.layoutDiagnostics, document: document)

            Spacer()

            ToolDebugCommandsView(document: document)

            if let switchboard = document.switchboard, document.selectedView == .overview {
                SwitchboarSettingsButton(document: document)
                SwitchboardEditButton(document: document, state: switchboard.state)
            }
            
            Menu("􁉽") {
                CommandSelectedView(viewType: .overview, label: "Switchboard")
                CommandSelectedView(viewType: .routes, label: "Routes")
                CommandSelectedView(viewType: .trains, label: "Trains")
                CommandSelectedView(viewType: .blocks, label: "Blocks")
                CommandSelectedView(viewType: .turnouts, label: "Turnouts")
                CommandSelectedView(viewType: .feedback, label: "Feedback")
                Divider()
                CommandSelectedView(viewType: .speed, label: "Speed Measurements")
            }
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
                document.disconnect()
            }
            .foregroundColor(.red)

            Spacer()
            
            SimulatorIndicationView(simulator: document.simulator)
                        
            Spacer()

            Button("Go") {
                document.enable() {}
            }
            .disabled(!document.connected)
            .help("Enable Power")
            .foregroundColor(.green)

            Button("Stop") {
                document.disable() {}
            }
            .disabled(!document.connected)
            .help("Disable Power")
            .foregroundColor(.red)
        } else {
            Button("Connect") {
                self.connectAlertShowing.toggle()
            }
            .foregroundColor(.green)
        }
    }
}

struct DiagnosticsIndicationView: View {
    
    @ObservedObject var diagnostics: LayoutDiagnostic
    @ObservedObject var document: LayoutDocument

    var body: some View {
        if diagnostics.hasErrors {
            Button("\(diagnostics.errorCount) 􀇾") {
                document.triggerLayoutDiagnostic.toggle()
            }
            .foregroundColor(.red)
            .help("The layout has some issues")
        } else {
            Button("􀁢") {
                document.triggerLayoutDiagnostic.toggle()
            }
            .foregroundColor(.green)
            .help("The layout is valid")
        }
    }
    
}

struct SimulatorIndicationView: View {
    
    @ObservedObject var simulator: MarklinCommandSimulator
    
    var body: some View {
        if simulator.started {
            Text("Running in Simulation Mode")
                .bold()
                .padding([.leading, .trailing])
                .background(simulator.enabled ? .green : .gray)
                .foregroundColor(.white)
                .clipShape(Capsule())
            Spacer()
        }
    }
}

struct CommandSelectedView: View {
    
    @AppStorage("selectedView") var selectedView: ViewType = .overview
    let viewType: ViewType
    let label: String
    
    var body: some View {
        let b = Binding {
            selectedView == viewType
        } set: {
            selectedView = $0 ? viewType : viewType
        }
        Toggle(label, isOn: b)
    }
}

struct ToolDebugCommandsView: View {
    
    @ObservedObject var document: LayoutDocument
    
    var body: some View {
        if document.showDebugModeControls {
            Menu("􀤊") {
                Button("Repair Layout") {
                    LayoutDiagnostic(layout: document.layout).repair()
                }
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
                state.editable.toggle()
            }.help("Edit Switchboard")
        }
    }
}

struct SwitchboarSettingsButton: View {
    
    @ObservedObject var document: LayoutDocument

    var body: some View {
        Button("􀋭") {
            document.triggerSwitchboardSettings.toggle()
        }.help("Switchboard Settings")
    }
    
}
