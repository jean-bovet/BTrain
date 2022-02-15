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

struct TrainSpeedView: View {
    
    let document: LayoutDocument
    let train: Train
    
    @ObservedObject var measurement: TrainSpeedMeasurement
    @ObservedObject var trainSpeed: TrainSpeed

    @State private var selection = Set<TrainSpeed.SpeedTableEntry.ID>()
    
    @Environment(\.presentationMode) var presentationMode

    func speedPath(in size: CGSize) -> Path {
        var p = Path()
        let xOffset = size.width / CGFloat(trainSpeed.speedTable.count)
        let yOffset = size.height / CGFloat(trainSpeed.speedTable.map({$0.speed}).max() ?? 1)
        for (index, speed) in trainSpeed.speedTable.enumerated() {
            let point = CGPoint(x: Double(index) * xOffset, y: Double(speed.speed) * yOffset)
            if p.isEmpty {
                p.move(to: point)
            } else {
                p.addLine(to: point)
            }
        }
        return p
    }
    
    var body: some View {
        VStack {
            HStack {
                Table(selection: $selection) {
                    TableColumn("Steps") { steps in
                        Text("\(steps.steps.value.wrappedValue)")
                    }.width(80)

                    TableColumn("Speed (km/h)") { step in
                        UndoProvider(step.speed) { speed in
                            TextField("Speed", value: speed, format: .number)
                                .labelsHidden()
                        }
                    }
                } rows: {
                    ForEach($trainSpeed.speedTable) { block in
                        TableRow(block)
                    }
                }
                .disabled(measurement.running)

                Canvas { context, size in
                    let flipVertical: CGAffineTransform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: size.height)
                    context.concatenate(flipVertical)
                    context.stroke(speedPath(in: size), with: .color(.blue))
                }
            }
            
            Divider()
            
            TrainSpeedMeasureView(document: document, layout: document.layout, train: train, selectedSpeedEntries: $selection, measurement: measurement)
            
            Divider()

            HStack {
                Spacer()
                Button("OK") {
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(measurement.running)
                .keyboardShortcut(.defaultAction)
            }
        }
        .onAppear {
            trainSpeed.updateSpeedStepsTable()
        }
    }
}

struct TrainSpeedMeasureFeedbackVisualView: View {

    let document: LayoutDocument

    @ObservedObject var feedback: Feedback
        
    var body: some View {
        Button("􀧷") {
            document.simulator.setFeedback(feedback: feedback, value: feedback.detected ? 0 : 1)
        }
        .buttonStyle(.borderless)
        .foregroundColor(feedback.detected ? .green : .black)
    }
}

struct TrainSpeedMeasureFeedbackView: View {

    let document: LayoutDocument
    let layout: Layout
    let label: String
    
    @ObservedObject var measurement: TrainSpeedMeasurement
    @Binding var feedbackUUID: String?
    
    var feedback: Feedback? {
        if let feedbackUUID = feedbackUUID, let feedback = layout.feedback(for: Identifier<Feedback>(uuid: feedbackUUID)) {
            return feedback
        } else {
            return nil
        }
    }
    
    var body: some View {
        VStack {
            Text(label)
            HStack {
                Picker(label, selection: $feedbackUUID) {
                    ForEach(layout.feedbacks, id:\.self) { feedback in
                        Text(feedback.name).tag(feedback.id.uuid as String?)
                    }
                }
                .labelsHidden()
                .disabled(measurement.running)
                if let feedback = self.feedback {
                    TrainSpeedMeasureFeedbackVisualView(document: document, feedback: feedback)
                }
            }
        }
    }
}

struct TrainSpeedMeasureDistanceView: View {

    @Binding var distance: Double
    @ObservedObject var measurement: TrainSpeedMeasurement

    var body: some View {
        VStack {
            Text("Distance")
            HStack {
                Text("􀅁")
                TextField("Distance:", value: $distance, format: .number)
                Text("cm 􀅂")
            }
            .disabled(measurement.running)
        }
    }
}

struct TrainSpeedMeasureView: View {
    
    let document: LayoutDocument
    let layout: Layout
    let train: Train

    @Binding var selectedSpeedEntries: Set<TrainSpeed.SpeedTableEntry.ID>

    @AppStorage("speedMeasureFeedbackA") private var feedbackA: String?
    @AppStorage("speedMeasureFeedbackB") private var feedbackB: String?
    @AppStorage("speedMeasureFeedbackC") private var feedbackC: String?

    @AppStorage("speedMeasureDistanceAB") private var distanceAB: Double = 0
    @AppStorage("speedMeasureDistanceBC") private var distanceBC: Double = 0

    @ObservedObject var measurement: TrainSpeedMeasurement
    
    @State private var error: String?
    @State private var progressInfo: String?
    @State private var progressValue: Double?
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("􀁟 Position the locomotive before feedback A with its travel direction towards A, B & C.")
            
            GroupBox {
                HStack {
                    TrainSpeedMeasureFeedbackView(document: document, layout: layout, label: "Feedback A", measurement: measurement, feedbackUUID: $feedbackA)
                    
                    TrainSpeedMeasureDistanceView(distance: $distanceAB, measurement: measurement)
                    
                    TrainSpeedMeasureFeedbackView(document: document, layout: layout, label: "Feedback B", measurement: measurement, feedbackUUID: $feedbackB)

                    TrainSpeedMeasureDistanceView(distance: $distanceBC, measurement: measurement)
                    
                    TrainSpeedMeasureFeedbackView(document: document, layout: layout, label: "Feedback C", measurement: measurement, feedbackUUID: $feedbackC)
                }
            }
                        
            HStack {
                if measurement.running {
                    Button("Cancel") {
                        measurement.cancel()
                    }
                } else {
                    Button("Measure") {
                        measure()
                    }.disabled(feedbackA == nil || feedbackB == nil || feedbackC == nil || selectedSpeedEntries.isEmpty)
                }

                if let progressValue = progressValue, measurement.running {
                    HStack {
                        ProgressView(value: progressValue)
                        if let progressInfo = progressInfo {
                            Text(progressInfo)
                        }
                    }
                } else {
                    if let error = error {
                        Text("􀇿 \(error)")
                    } else if selectedSpeedEntries.isEmpty {
                        Text("􀇿 Select one or more steps in the table above")
                    } else if feedbackA == nil {
                        Text("􀇿 Select feedback A")
                    } else if feedbackB == nil {
                        Text("􀇿 Select feedback B")
                    } else if feedbackC == nil {
                        Text("􀇿 Select feedback C")
                    } else {
                        if selectedSpeedEntries.count == 1 {
                            Text("Ready to measure one step")
                        } else {
                            Text("Ready to measure \(selectedSpeedEntries.count) steps")
                        }
                    }
                }
            }
        }
    }
    
    func measure() {
        if let feedbackA = feedbackA, let feedbackB = feedbackB, let feedbackC = feedbackC {
            let properties = TrainSpeedMeasurement.Properties(train: train, selectedSpeedEntries: selectedSpeedEntries, feedbackA: Identifier<Feedback>(uuid: feedbackA), feedbackB: Identifier<Feedback>(uuid: feedbackB), feedbackC: Identifier<Feedback>(uuid: feedbackC), distanceAB: distanceAB, distanceBC: distanceBC)
            self.error = nil
            do {
                try measurement.start(properties: properties) { info, progress in
                    self.progressInfo = info
                    self.progressValue = progress
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

struct TrainSpeedView_Previews: PreviewProvider {
        
    static let doc = LayoutDocument(layout: LayoutFCreator().newLayout())
    
    static var previews: some View {
        TrainSpeedView(document: doc, train: Train(), measurement: doc.trainSpeedMeasurement, trainSpeed: TrainSpeed(decoderType: .MFX))
    }
}
