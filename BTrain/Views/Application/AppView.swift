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

struct AppView: View {

    @ObservedObject var document: LayoutDocument

    @State private var showNewLayoutSheet = false
    @State private var connectAlertShowing = false
    @State private var showDiagnosticsSheet = false
    @State private var showDiscoverLocomotiveConfirmation = false
    @State private var repairLayoutTrigger = false

    var body: some View {
        Group {
            switch(document.selectedView) {
            case .switchboard:
                OverviewView(document: document)
            case .routes:
                RouteListView(layout: document.layout)
            case .locomotives:
                TrainEditListView(layout: document.layout)
            case .blocks:
                BlockEditListView(layout: document.layout)
            case .turnouts:
                TurnoutEditListView(layout: document.layout)
            case .feedback:
                FeedbackEditListView(layout: document.layout)
            case .feedbackMonitor:
                FeedbackMonitorView(layout: document.layout)
            }
        }
        .onChange(of: document.diagnostics, perform: { v in
            if document.diagnostics {
                showDiagnosticsSheet = true
                document.diagnostics = false
            }
        })
        .onChange(of: document.repairLayoutTrigger, perform: { v in
            if document.repairLayoutTrigger {
                LayoutDiagnostic(layout: document.layout).repair()
                document.repairLayoutTrigger = false
            }
        })
        .onChange(of: document.discoverLocomotiveConfirmation, perform: { v in
            if document.discoverLocomotiveConfirmation {
                if document.layout.trains.isEmpty {
                    document.coordinator?.discoverLocomotives()
                } else {
                    showDiscoverLocomotiveConfirmation.toggle()
                }
                document.discoverLocomotiveConfirmation = false
            }
        })
        .onChange(of: document.importPredefinedLayout, perform: { v in
            if document.importPredefinedLayout {
                showNewLayoutSheet.toggle()
                document.importPredefinedLayout = false
            }
        })
        .onAppear {
            if UserDefaults.standard.bool(forKey: "autoConnectSimulator") {
                document.connectToSimulator() { error in
                    if UserDefaults.standard.bool(forKey: "autoEnableSimulator") {
                        document.enable() {}
                    }
                }
            }
        }.toolbar {
            DocumentToolbarContent(document: document,
                                   connectAlertShowing: $connectAlertShowing)
        }.sheet(isPresented: $connectAlertShowing) {
            ConnectSheet(document: document)
                .padding()
        }.sheet(isPresented: $showNewLayoutSheet) {
            ImportLayoutSheet(document: document)
                .padding()
        }.sheet(isPresented: $showDiagnosticsSheet) {
            DiagnosticsSheet(layout: document.layout)
                .padding()
        }.alert("Are you sure you want to replace the current list of locomotives with the locomotives definition from the Central Station?", isPresented: $showDiscoverLocomotiveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Download & Replace", role: .destructive) {
                document.coordinator?.discoverLocomotives()
            }
        }
    }
    
}

struct AppView_Previews: PreviewProvider {
    static var previews: some View {
        AppView(document: LayoutDocument(layout: Layout()))
    }
}
