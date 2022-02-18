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
    
    let measurement: TrainSpeedMeasurement

    @Binding var running: Bool
    
    @State private var progressInfo: String?
    @State private var progressValue: Double?
    
    var body: some View {
        VStack(alignment: .leading) {
            if let progressInfo = progressInfo {
                Text(progressInfo)
            } else {
                Text("􀁟 Position locomotive \"\(measurement.train.name)\" before feedback A with its travel direction towards A, B & C.")
            }

            HStack {
                if running {
                    Button("Cancel") {
                        running = false
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
        measurement.start() { info in
            if info.step == .done {
                self.progressInfo = nil
                self.running = false
            } else {
                self.progressInfo = "Measuring speed for step \(info.speedEntry.steps.value)"
                self.progressValue = info.progress
            }
        }
    }

    func cancel() {
        measurement.cancel()
        progressInfo = nil
    }
}

struct TrainSpeedMeasureControlsView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutFCreator().newLayout())
    static let measurement = TrainSpeedMeasurement(layout: doc.layout, interface: doc.interface, train: doc.layout.trains[0], speedEntries: [10],
                                                   feedbackA: Identifier<Feedback>(uuid: "OL1.1"), feedbackB: Identifier<Feedback>(uuid: "OL1.1"), feedbackC: Identifier<Feedback>(uuid: "OL1.1"),
                                                   distanceAB: 10, distanceBC: 20)
    static var previews: some View {
        TrainSpeedMeasureControlsView(measurement: measurement, running: .constant(false))
    }
}
