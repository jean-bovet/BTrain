// Copyright 2021 Jean Bovet
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

struct DocumentToolbarContent: ToolbarContent {

    @ObservedObject var document: LayoutDocument
    
    @Binding var connectAlertShowing: Bool
    
    var body: some ToolbarContent {
        ToolbarItemGroup {
            ConnectCommandsView(document: document, connectAlertShowing: $connectAlertShowing)
        }
        
        ToolbarItemGroup {
            Menu("View") {
                CommandSelectedView(viewType: .switchboard, label: "Switchboard")
                CommandSelectedView(viewType: .routes, label: "Routes")
                CommandSelectedView(viewType: .locomotives, label: "Trains")
                CommandSelectedView(viewType: .blocks, label: "Blocks")
                CommandSelectedView(viewType: .turnouts, label: "Turnouts")
                CommandSelectedView(viewType: .feedback, label: "Feedback")
                CommandSelectedView(viewType: .feedbackMonitor, label: "Feedback Monitor")
            }
                        
            Menu("Tools") {
                Button("Validate Layout") {
                    document.diagnostics.toggle()
                }

                Divider()
                
                Button("Import Locomotives") {
                    document.discoverLocomotiveConfirmation.toggle()
                }
                
                ToolDebugCommandsView(document: document)
            }

            if let switchboard = document.switchboard {
                Menu("Switchboard") {
                    CommandEditSwitchboardView(state: switchboard.state)

                    Divider()

                    CommandShowBlockNameView()
                    CommandShowTurnoutNameView()
                }.disabled(document.selectedView != .switchboard)
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
            SimulatorIndicationView(simulator: document.simulator)
            
            Button("Disconnect") {
                document.disconnect()
            }
        } else {
            Button("Connect") {
                self.connectAlertShowing.toggle()
            }
        }

        Spacer()

        Button("Enable") {
            document.enable()
        }.disabled(!document.connected)

        Button("Disable") {
            document.disable()
        }.disabled(!document.connected)
    }
}

struct SimulatorIndicationView: View {
    
    @ObservedObject var simulator: MarklinCommandSimulator
    
    var body: some View {
        if simulator.started {
            Text("Running in Simulation Mode")
                .bold()
                .padding([.leading, .trailing])
                .background(simulator.enabled ? .green : .red)
                .foregroundColor(.white)
                .clipShape(Capsule())
            Spacer()
        }
    }
}

struct CommandSelectedView: View {
    
    @AppStorage("selectedView") var selectedView: LayoutDocument.ViewType = .switchboard
    let viewType: LayoutDocument.ViewType
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
        if document.debugMode {
            Divider()

            Button("Repair Layout") {
                document.repairLayoutTrigger.toggle()
            }
            
            Divider()

            Button("Generate Swift Code") {
                let code = Layout2Swift(layout: document.layout).swift()
                NSPasteboard.general.declareTypes([.string], owner: nil)
                NSPasteboard.general.setString(code, forType: .string)
            }
        }
    }
}

struct CommandEditSwitchboardView: View {
    
    @ObservedObject var state: SwitchBoard.State
    
    var body: some View {
        let b = Binding {
            state.editable
        } set: {
            state.editable = $0
        }
        Toggle("Edit", isOn: b)
    }
}

struct CommandShowBlockNameView: View {
    
    @AppStorage("showBlockName") var state: Bool = false
    
    var body: some View {
        Toggle("Show Block Name", isOn: $state)
    }
}

struct CommandShowTurnoutNameView: View {
    
    @AppStorage("showTurnoutName") var state: Bool = false

    var body: some View {
        Toggle("Show Turnout Name", isOn: $state)
    }
}
