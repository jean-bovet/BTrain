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

struct SettingsView: View {
    
    private enum Tabs: Hashable {
        case general, speed, routing, advanced
    }

    @AppStorage(SettingsKeys.autoConnectSimulator) private var autoConnectSimulator = false
    @AppStorage(SettingsKeys.autoEnableSimulator) private var autoEnableSimulator = false
    @AppStorage(SettingsKeys.fontSize) private var fontSize = 12.0

    @AppStorage(SettingsKeys.maximumSpeed) private var maximumSpeed = Int(LayoutFactory.DefaultMaximumSpeed)
    @AppStorage(SettingsKeys.limitedSpeed) private var limitedSpeed = Int(LayoutFactory.DefaultLimitedSpeed)
    @AppStorage(SettingsKeys.brakingSpeed) private var brakingSpeed = Int(LayoutFactory.DefaultBrakingSpeed)

    @AppStorage(SettingsKeys.automaticRouteRandom) private var automaticRouteRandom = true
    @AppStorage(SettingsKeys.detectUnexpectedFeedback) var detectUnexpectedFeedback = true
    @AppStorage(SettingsKeys.strictRouteFeedbackStrategy) var strictRouteFeedbackStrategy = false

    @AppStorage(SettingsKeys.debugMode) private var showDebugControls = false
    @AppStorage(SettingsKeys.recordDiagnosticLogs) private var recordDiagnosticLogs = false
    @AppStorage(SettingsKeys.logRoutingResolutionSteps) private var logRoutingResolutionSteps = false

    var body: some View {
        TabView {
            Form {
                Toggle("Connect to Simulator At Startup", isOn: $autoConnectSimulator)
                
                HStack {
                    Spacer().fixedSpace()
                    Toggle("Enable Simulator", isOn: $autoEnableSimulator)
                        .disabled(!autoConnectSimulator)
                }

                Slider(value: $fontSize, in: 9...96) {
                    Text("Font Size (\(fontSize, specifier: "%.0f") pts)")
                }
            }
            .tabItem {
                Label("General", systemImage: "gear")
            }
            .tag(Tabs.general)

            Form {
                TextField("Maximum Speed:", value: $maximumSpeed, format: .number)
                    .unitStyle("kph")
                TextField("Limited Speed:", value: $limitedSpeed, format: .number)
                    .unitStyle("kph")
                TextField("Braking Speed:", value: $brakingSpeed, format: .number)
                    .unitStyle("kph")
            }
            .tabItem {
                Label("Speed", systemImage: "speedometer")
            }
            .tag(Tabs.speed)
           
            Form {
                Toggle("Generate Automatic Route at Random", isOn: $automaticRouteRandom)
                Toggle("Detect Unexpected Feedbacks", isOn: $detectUnexpectedFeedback)
                Toggle("Strict Route Feedback Detection", isOn: $strictRouteFeedbackStrategy)
            }
            .tabItem {
                Label("Routing", systemImage: "point.topleft.down.curvedto.point.filled.bottomright.up")
            }
            .tag(Tabs.routing)
           
            Form {
                Toggle("Show Debug Controls", isOn: $showDebugControls)
                Toggle("Record Diagnostic Logs", isOn: $recordDiagnosticLogs)
                Toggle("Log Routing Resolution Steps", isOn: $logRoutingResolutionSteps)
            }
            .tabItem {
                Label("Advanced", systemImage: "star")
            }
            .tag(Tabs.advanced)
        }
        .padding(20)
        .frame(width: 450, height: 160)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
