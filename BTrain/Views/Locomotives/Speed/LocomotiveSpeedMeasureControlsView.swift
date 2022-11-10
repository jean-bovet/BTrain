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

struct LocomotiveSpeedMeasureControlsView: View {
    
    let document: LayoutDocument
    let loc: Locomotive
    @Binding var speedEntries: Set<LocomotiveSpeed.SpeedTableEntry.ID>
    let feedbackA: String
    let feedbackB: String
    let feedbackC: String
    @Binding var distanceAB: Double
    @Binding var distanceBC: Double

    @Binding var running: Bool
    @Binding var currentSpeedEntry: LocomotiveSpeed.SpeedTableEntry?
    
    @State private var progressInfo: String?
    @State private var progressValue: Double?
    
    var feedbackAName: String {
        feedbackName(feedbackID: feedbackA, defaultName: "A")
    }
    
    var feedbackBName: String {
        feedbackName(feedbackID: feedbackB, defaultName: "B")
    }
    
    var feedbackCName: String {
        feedbackName(feedbackID: feedbackC, defaultName: "C")
    }
    
    var body: some View {
        HStack {
            if let progressInfo = progressInfo {
                Text(progressInfo)
            } else {
                Text("􀁟 Position locomotive \"\(loc.name)\" before feedback \(feedbackAName) with its travel direction towards \(feedbackAName) 􀄫 \(feedbackBName) 􀄫 \(feedbackCName).")
            }
            
            Spacer()
            
            if running {
                if let progressValue = progressValue {
                    ProgressView(value: progressValue)
                }
                Button("Cancel") {
                    cancel()
                }
            } else {
                Button("Measure") {
                    running = true
                    measure()
                }
            }
        }
    }
    
    private func feedbackName(feedbackID: String, defaultName: String) -> String {
        if let name = document.layout.feedback(for: .init(uuid: feedbackID))?.name {
            return name
        } else {
            return defaultName
        }
    }

    private func measure() {
        document.measurement = LocomotiveSpeedMeasurement(layout: document.layout, executor: document.layoutController, interface: document.interface, loc: loc, speedEntries: speedEntries,
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

    private func cancel() {
        document.measurement?.cancel()
        done()
    }
    
    private func done() {
        progressInfo = nil
        running = false
        currentSpeedEntry = nil
    }
}

struct LocomotiveSpeedMeasureControlsView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutComplex().newLayout())
    static let measurement = LocomotiveSpeedMeasurement(layout: doc.layout, executor: doc.layoutController, interface: doc.interface, loc: doc.layout.locomotives[0], speedEntries: [10],
                                                   feedbackA: Identifier<Feedback>(uuid: "OL1.1"), feedbackB: Identifier<Feedback>(uuid: "OL1.1"), feedbackC: Identifier<Feedback>(uuid: "OL1.1"),
                                                   distanceAB: 10, distanceBC: 20)
    static var previews: some View {
        LocomotiveSpeedMeasureControlsView(document: doc, loc: doc.layout.locomotives[0], speedEntries: .constant([]),
                                      feedbackA: "a", feedbackB: "b", feedbackC: "c", distanceAB: .constant(0), distanceBC: .constant(0),
                                      running: .constant(false), currentSpeedEntry: .constant(nil))
    }
}
