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

struct LocomotiveSpeedTableView: View {
    @Binding var selection: Set<LocomotiveSpeed.SpeedTableEntry.ID>
    @Binding var currentSpeedEntry: LocomotiveSpeed.SpeedTableEntry?

    @ObservedObject var trainSpeed: LocomotiveSpeed

    var body: some View {
        VStack {
            Table(of: Binding<LocomotiveSpeed.SpeedTableEntry>.self, selection: $selection) {
                TableColumn("Steps") { steps in
                    Text("\(steps.steps.value.wrappedValue)")
                }.width(80)

                TableColumn("Speed (km/h)") { step in
                    HStack {
                        UndoProvider(step.speed) { speed in
                            TextField("", value: speed, format: .number)
                                .labelsHidden()
                        }
                        if let currentSpeedEntry = currentSpeedEntry, currentSpeedEntry.steps.value == step.steps.value.wrappedValue {
                            Text("􀐫")
                        }
                    }
                }
            } rows: {
                ForEach($trainSpeed.speedTable) { block in
                    TableRow(block)
                }
            }
            HStack {
                Button("􁂥") {
                    trainSpeed.updateSpeedStepsTable()
                    trainSpeed.interpolateSpeedTable()
                }
                .help("Interpolate Missing Speed Values")

                Button("􀈂") {
                    exportTable()
                }
                .help("Export Table")

                Button("􀈄") {
                    importTable()
                }
                .help("Import Table")

                Spacer()

                Button("􀈑") {
                    selection.forEach { index in
                        trainSpeed.speedTable[Int(index)].speed = nil
                    }
                }
                .help("Remove Speed Value")
                .disabled(selection.isEmpty)
            }
        }
    }

    private func exportTable() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.canCreateDirectories = true
        savePanel.title = "Export Speed Table"
        let response = savePanel.runModal()
        if let url = savePanel.url, response == .OK {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(trainSpeed.speedTable)
                try data.write(to: url)
            } catch {
                BTLogger.error("Error exporting Speed Table: \(error)")
            }
        }
    }

    private func importTable() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.title = "Import Speed Table"
        let response = openPanel.runModal()
        if let url = openPanel.url, response == .OK {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                trainSpeed.speedTable = try decoder.decode([LocomotiveSpeed.SpeedTableEntry].self, from: data)
            } catch {
                BTLogger.error("Error importing Speed Table: \(error)")
            }
        }
    }
}

struct LocomotiveSpeedTableView_Previews: PreviewProvider {
    static let doc = LayoutDocument(layout: LayoutComplex().newLayout())

    static var previews: some View {
        LocomotiveSpeedTableView(selection: .constant([]),
                                 currentSpeedEntry: .constant(nil),
                                 trainSpeed: doc.layout.locomotives[0].speed)
    }
}
