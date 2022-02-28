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

struct SwitchboardRuntimeErrorView: View {
    
    let debugger: LayoutControllerDebugger
    
    @Binding var error: String?
    
    @State private var exportError: String?
    
    func exportDiagnosticLogs() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.canCreateDirectories = true
        savePanel.title = "Export Diagnostic Logs"
        let response = savePanel.runModal()
        if let url = savePanel.url, response == .OK {
            do {
                try debugger.save(to: url)
                exportError = nil
            } catch {
                exportError = error.localizedDescription
            }
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                if let error = error {
                    Text("\(error)")
                    Spacer()
                }
                
                Button("Export Diagnostic Logs…") {
                    exportDiagnosticLogs()
                }
                
                Button("OK") {
                    error = nil
                }
            }
            
            if let exportError = exportError {
                Text("\(exportError)")
                Spacer()
            }
        }
        .padding()
        .background(.orange)
    }
}

struct LayoutRuntimeErrorView_Previews: PreviewProvider {
    static var previews: some View {
        SwitchboardRuntimeErrorView(debugger: LayoutControllerDebugger(layout: Layout()), error: .constant("Unexpected feedback IL2.1 detected"))
    }
}
