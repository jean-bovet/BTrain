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
struct DocumentView: View {

    @ObservedObject var document: LayoutDocument
    
    @State private var showNewWizard = false
    @State private var connectAlertShowing = false
    @State private var showDiagnosticsSheet = false
    @State private var repairLayoutTrigger = false
    
    @AppStorage(SettingsKeys.autoConnectSimulator) private var autoConnectSimulator = false
    @AppStorage(SettingsKeys.autoEnableSimulator) private var autoEnableSimulator = false
    
    var idealSheetWidth: CGFloat {
        (NSApp.keyWindow?.contentView?.bounds.width ?? 500) * 0.75
    }
    
    var idealSheetHeight: CGFloat {
        (NSApp.keyWindow?.contentView?.bounds.height ?? 400) * 0.75
    }

    var body: some View {
        OverviewView(document: document)
            .onChange(of: document.triggerLayoutDiagnostic, perform: { v in
                if document.triggerLayoutDiagnostic {
                    showDiagnosticsSheet = true
                    document.triggerLayoutDiagnostic = false
                }
            })
            .onAppear {
                if document.newDocument {
                    showNewWizard.toggle()
                }
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
            }.sheet(isPresented: $showNewWizard) {
                NewLayoutWizardView(document: document)
                    .padding()
            }.sheet(isPresented: $document.displaySheet) {
                displaySheetView
                    .frame(idealWidth: idealSheetWidth, idealHeight: idealSheetHeight)
            }
    }
    
    var displaySheetView: some View {
        ConfigurationSheet(title: document.displaySheetType.rawValue) {
            switch document.displaySheetType {
            case .layoutScripts:
                LayoutScriptEditingView(doc: document, layout: document.layout)
            case .routeScripts:
                RouteScriptEditingView(layout: document.layout)
            case .routes:
                RouteListView(layout: document.layout)
            case .trains:
                TrainEditingView(document: document, layout: document.layout)
            case .locomotives:
                LocomotiveListView(document: document, layout: document.layout)
            case .stations:
                StationListView(layout: document.layout)
            case .blocks:
                BlockListView(layout: document.layout)
            case .turnouts:
                TurnoutListView(doc: document, layout: document.layout)
            case .feedbacks:
                FeedbackEditListView(doc: document, layout: document.layout, layoutController: document.layoutController)
            case .cs3:
                CS3DebuggerView(doc: document)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        DocumentView(document: LayoutDocument(layout: Layout()))
    }
}
