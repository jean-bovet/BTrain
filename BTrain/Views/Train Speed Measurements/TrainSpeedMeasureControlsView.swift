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
    
    let layout: Layout
    let train: Train
    
    @ObservedObject var measurement: TrainSpeedMeasurement

    @Binding var selectedSpeedEntries: Set<TrainSpeed.SpeedTableEntry.ID>

    @Binding var feedbackA: String?
    @Binding var feedbackB: String?
    @Binding var feedbackC: String?

    @Binding var distanceAB: Double
    @Binding var distanceBC: Double

    @State private var error: String?
    @State private var progressInfo: String?
    @State private var progressValue: Double?
    
    var validationError: String? {
        if selectedSpeedEntries.isEmpty {
            return "􀇿 One or more steps must be selected"
        } else if feedbackA == nil {
            return "􀇿 Select feedback A"
        } else if feedbackB == nil {
            return "􀇿 Select feedback B"
        } else if feedbackC == nil {
            return "􀇿 Select feedback C"
        } else {
            return nil
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            if let validationError = validationError {
                Text(validationError)
            } else {
                if let error = error {
                    Text("􀇿 \(error)")
                } else if let progressInfo = progressInfo {
                    Text(progressInfo)
                } else {
                    Text("􀁟 Position locomotive \"\(train.name)\" before feedback A with its travel direction towards A, B & C.")
                }

                HStack {
                    if measurement.running {
                        Button("Cancel") {
                            cancel()
                        }
                    } else {
                        Button("Measure") {
                            measure()
                        }.disabled(feedbackA == nil || feedbackB == nil || feedbackC == nil || selectedSpeedEntries.isEmpty)
                    }

                    if let progressValue = progressValue, measurement.running {
                        HStack {
                            ProgressView(value: progressValue)
                        }
                    }
                }
            }
        }
    }
    
    func measure() {
        if let feedbackA = feedbackA, let feedbackB = feedbackB, let feedbackC = feedbackC {
            let properties = TrainSpeedMeasurement.Properties(train: train,
                                                              selectedSpeedEntries: selectedSpeedEntries,
                                                              feedbackA: Identifier<Feedback>(uuid: feedbackA),
                                                              feedbackB: Identifier<Feedback>(uuid: feedbackB),
                                                              feedbackC: Identifier<Feedback>(uuid: feedbackC),
                                                              distanceAB: distanceAB,
                                                              distanceBC: distanceBC)
            self.error = nil
            do {
                try measurement.start(properties: properties) { info in
                    self.progressInfo = "Measuring speed for step \(info.speedEntry.steps.value)"
                    self.progressValue = info.progress
                }
            } catch {
                self.error = error.localizedDescription
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

    static var previews: some View {
        TrainSpeedMeasureControlsView(layout: doc.layout, train: doc.layout.trains[0], measurement: doc.trainSpeedMeasurement, selectedSpeedEntries: .constant([10]), feedbackA: .constant("OL1.1"), feedbackB: .constant("OL1.2"), feedbackC: .constant("OL2.1"), distanceAB: .constant(0), distanceBC: .constant(0))
    }
}
