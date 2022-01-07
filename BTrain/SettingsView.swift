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
        case general, advanced
    }

    @AppStorage("automaticRouteRandom") private var automaticRouteRandom = true
    @AppStorage("detectUnexpectedFeedback") var detectUnexpectedFeedback = true
    @AppStorage("strictRouteFeedbackStrategy") var strictRouteFeedbackStrategy = true

    @AppStorage("autoConnectSimulator") private var autoConnectSimulator = false
    @AppStorage("autoEnableSimulator") private var autoEnableSimulator = false
    @AppStorage("debugMode") private var showDebugControls = false
    @AppStorage("fontSize") private var fontSize = 12.0

    var body: some View {
        TabView {
            Form {
                Toggle("Generate Automatic Route at Random", isOn: $automaticRouteRandom)

                Toggle("Detect Unexpected Feedbacks", isOn: $detectUnexpectedFeedback)

                Toggle("Strict Route Feedback Detection", isOn: $strictRouteFeedbackStrategy)

                Slider(value: $fontSize, in: 9...96) {
                    Text("Font Size (\(fontSize, specifier: "%.0f") pts)")
                }
            }
            .tabItem {
                Label("General", systemImage: "gear")
            }
            .tag(Tabs.general)
            
            Form {
                Toggle("Connect to Simulator At Startup", isOn: $autoConnectSimulator)
                HStack {
                    Spacer().fixedSpace()
                    Toggle("Enable Simulator", isOn: $autoEnableSimulator)
                        .disabled(!autoConnectSimulator)
                }
                Toggle("Show Debug Controls", isOn: $showDebugControls)
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
