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

let SideListFixedWidth = 400.0

// This is the main application view. It knows how to switch between views and how to respond to most of the commands.
struct MainView: View {

    @ObservedObject var document: LayoutDocument
    
    @State private var connectAlertShowing = false
    @State private var showDiagnosticsSheet = false
    @State private var showDiscoverLocomotiveConfirmation = false
    @State private var repairLayoutTrigger = false
    
    @AppStorage(SettingsKeys.autoConnectSimulator) private var autoConnectSimulator = false
    @AppStorage(SettingsKeys.autoEnableSimulator) private var autoEnableSimulator = false
    
    var body: some View {
        Group {
            switch(document.selectedView) {
            case .overview:
                OverviewView(document: document)
            case .routes:
                RouteListView(layout: document.layout)
            case .trains:
                TrainListView(document: document, layout: document.layout)
            case .blocks:
                BlockListView(layout: document.layout)
            case .turnouts:
                TurnoutListView(layout: document.layout)
            case .feedback:
                FeedbackEditListView(layout: document.layout)
            case .speed:
                TrainSpeedMeasurementsView(document: document, layout: document.layout)
            }
        }
        .onChange(of: document.triggerLayoutDiagnostic, perform: { v in
            if document.triggerLayoutDiagnostic {
                showDiagnosticsSheet = true
                document.triggerLayoutDiagnostic = false
            }
        })
        .onChange(of: document.triggerRepairLayout, perform: { v in
            if document.triggerRepairLayout {
                LayoutDiagnostic(layout: document.layout).repair()
                document.triggerRepairLayout = false
            }
        })
        .onChange(of: document.discoverLocomotiveConfirmation, perform: { v in
            if document.discoverLocomotiveConfirmation {
                if document.layout.trains.isEmpty {
                    document.layoutController.discoverLocomotives(merge: false)
                } else {
                    showDiscoverLocomotiveConfirmation.toggle()
                }
                document.discoverLocomotiveConfirmation = false
            }
        })
        .onAppear {
            if autoConnectSimulator {
                document.connectToSimulator(enable: autoEnableSimulator)
            }
        }.toolbar {
            DocumentToolbarContent(document: document,
                                   connectAlertShowing: $connectAlertShowing)
        }.sheet(isPresented: $connectAlertShowing) {
            ConnectSheet(document: document, onConnectTasks: document.onConnectTasks)
                .padding()
        }.sheet(isPresented: $showDiagnosticsSheet) {
            DiagnosticsSheet(layout: document.layout, options: .all)
                .padding()
        }.sheet(isPresented: $document.triggerSwitchboardSettings) {
            SwitchboardSettingsView()
                .padding()
        }.alert("Are you sure you want to change the current list of locomotives with the locomotives definition from the Central Station?", isPresented: $showDiscoverLocomotiveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Download & Merge") {
                document.layoutController.discoverLocomotives(merge: true)
            }
            Button("Download & Replace", role: .destructive) {
                document.layoutController.discoverLocomotives(merge: false)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        MainView(document: LayoutDocument(layout: Layout()))
    }
}
