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
        case general, speed, routing, logging, advanced
    }

    @AppStorage(SettingsKeys.autoConnectSimulator) private var autoConnectSimulator = false
    @AppStorage(SettingsKeys.autoEnableSimulator) private var autoEnableSimulator = false
    @AppStorage(SettingsKeys.fontSize) private var fontSize = 12.0

    @AppStorage(SettingsKeys.maximumSpeed) private var maximumSpeed = Int(LayoutFactory.DefaultMaximumSpeed)
    @AppStorage(SettingsKeys.limitedSpeed) private var limitedSpeed = Int(LayoutFactory.DefaultLimitedSpeed)
    @AppStorage(SettingsKeys.brakingSpeed) private var brakingSpeed = Int(LayoutFactory.DefaultBrakingSpeed)

    @AppStorage(SettingsKeys.automaticRouteRandom) private var automaticRouteRandom = true
    @AppStorage(SettingsKeys.shortestRouteEnabled) private var shortestRouteEnabled = false
    @AppStorage(SettingsKeys.detectUnexpectedFeedback) var detectUnexpectedFeedback = true
    @AppStorage(SettingsKeys.strictRouteFeedbackStrategy) var strictRouteFeedbackStrategy = false

    @AppStorage(SettingsKeys.debugMode) private var showDebugControls = false
    @AppStorage(SettingsKeys.recordDiagnosticLogs) private var recordDiagnosticLogs = false
    @AppStorage(SettingsKeys.logRoutingResolutionSteps) private var logRoutingResolutionSteps = false
    @AppStorage(SettingsKeys.logReservation) private var logReservation = false
    @AppStorage(SettingsKeys.logUnknownMessages) private var logUnknownMessages = false
    
    @AppStorage(SettingsKeys.logCategoryNetwork) private var logCategoryNetwork = false
    @AppStorage(SettingsKeys.logCategoryRouter) private var logCategoryRouter = false
    @AppStorage(SettingsKeys.logCategorySpeed) private var logCategorySpeed = false
    @AppStorage(SettingsKeys.logCategoryReservation) private var logCategoryReservation = false

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
                Toggle("Find the Shortest Possible Route", isOn: $shortestRouteEnabled)
                Toggle("Generate Automatic Route at Random", isOn: $automaticRouteRandom)
                Toggle("Detect Unexpected Feedbacks", isOn: $detectUnexpectedFeedback)
                Toggle("Strict Route Feedback Detection", isOn: $strictRouteFeedbackStrategy)
            }
            .tabItem {
                Label("Routing", systemImage: "point.topleft.down.curvedto.point.filled.bottomright.up")
            }
            .tag(Tabs.routing)
           
            Form {
                Toggle("Record Diagnostic Logs", isOn: $recordDiagnosticLogs)
                Toggle("Log Routing Resolution Steps", isOn: $logRoutingResolutionSteps)
                Toggle("Log Block and Turnout Reservation", isOn: $logReservation)
                Toggle("Log Unknown Digital Controller Commands", isOn: $logUnknownMessages)
                Section(header: Text("Log Category")) {
                    Toggle("Network", isOn: $logCategoryNetwork)
                    Toggle("Router", isOn: $logCategoryRouter)
                    Toggle("Speed", isOn: $logCategorySpeed)
                    Toggle("Reservation", isOn: $logCategoryReservation)
                }
            }
            .onChange(of: logCategoryNetwork, perform: { _ in BTLogger.updateLoggerInstances() })
            .onChange(of: logCategoryRouter, perform: { _ in BTLogger.updateLoggerInstances() })
            .onChange(of: logCategorySpeed, perform: { _ in BTLogger.updateLoggerInstances() })
            .onChange(of: logCategoryReservation, perform: { _ in BTLogger.updateLoggerInstances() })
            .tabItem {
                Label("Logging", systemImage: "doc.text.fill")
            }
            .tag(Tabs.advanced)
            
            Form {
                Toggle("Developer Tools", isOn: $showDebugControls)
            }
            .tabItem {
                Label("Advanced", systemImage: "star")
            }
            .tag(Tabs.advanced)
        }
        .padding(20)
        .frame(width: 450, height: 240)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
