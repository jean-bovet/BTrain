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

struct TrainSpeedMeasureControlsView: View {
    
    let document: LayoutDocument
    let train: Train
    @Binding var speedEntries: Set<TrainSpeed.SpeedTableEntry.ID>
    let feedbackA: String
    let feedbackB: String
    let feedbackC: String
    @Binding var distanceAB: Double
    @Binding var distanceBC: Double

    @Binding var running: Bool
    @Binding var currentSpeedEntry: TrainSpeed.SpeedTableEntry?
    
    @State private var progressInfo: String?
    @State private var progressValue: Double?
    
    var body: some View {
        VStack(alignment: .leading) {
            if let progressInfo = progressInfo {
                Text(progressInfo)
            } else {
                Text("􀁟 Position locomotive \"\(train.name)\" before feedback A with its travel direction towards A, B & C.")
            }

            HStack {
                if running {
                    Button("Cancel") {
                        cancel()
                    }
                } else {
                    Button("Measure") {
                        running = true
                        measure()
                    }
                }

                if let progressValue = progressValue, running {
                    HStack {
                        ProgressView(value: progressValue)
                    }
                }
            }
        }
    }
    
    func measure() {
        document.measurement = TrainSpeedMeasurement(layout: document.layout, executor: document.layoutController, interface: document.interface, train: train, speedEntries: speedEntries,
                                                feedbackA: Identifier<Feedback>(uuid: feedbackA), feedbackB: Identifier<Feedback>(uuid: feedbackB), feedbackC: Identifier<Feedback>(uuid: feedbackC),
                                                distanceAB: distanceAB, distanceBC: distanceBC)
        document.measurement?.start { info in
            if info.step == .done {
                self.done()
            } else {
                self.progressInfo = "Measuring speed for step \(info.speedEntry.steps.value)"
                self.progressValue = info.progress
                self.currentSpeedEntry = info.speedEntry
            }
        }
    }

    func cancel() {
        document.measurement?.cancel()
        done()
    }
    
    func done() {
        progressInfo = nil
        running = false
        currentSpeedEntry = nil
    }
}

struct TrainSpeedMeasureControlsView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutComplex().newLayout())
    static let measurement = TrainSpeedMeasurement(layout: doc.layout, executor: doc.layoutController, interface: doc.interface, train: doc.layout.trains[0], speedEntries: [10],
                                                   feedbackA: Identifier<Feedback>(uuid: "OL1.1"), feedbackB: Identifier<Feedback>(uuid: "OL1.1"), feedbackC: Identifier<Feedback>(uuid: "OL1.1"),
                                                   distanceAB: 10, distanceBC: 20)
    static var previews: some View {
        TrainSpeedMeasureControlsView(document: doc, train: doc.layout.trains[0], speedEntries: .constant([]),
                                      feedbackA: "a", feedbackB: "b", feedbackC: "c", distanceAB: .constant(0), distanceBC: .constant(0),
                                      running: .constant(false), currentSpeedEntry: .constant(nil))
    }
}
