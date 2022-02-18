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

struct TrainSpeedMeasurementsView: View {
    
    let document: LayoutDocument
    let layout: Layout

    @State private var selectedSpeedEntries = Set<TrainSpeed.SpeedTableEntry.ID>()

    @AppStorage("speedMeasureFeedbackA") private var feedbackA: String?
    @AppStorage("speedMeasureFeedbackB") private var feedbackB: String?
    @AppStorage("speedMeasureFeedbackC") private var feedbackC: String?

    @AppStorage("speedMeasureDistanceAB") private var distanceAB: Double = 0
    @AppStorage("speedMeasureDistanceBC") private var distanceBC: Double = 0
        
    @AppStorage("speedMeasureSelectedTrain") private var selectedTrain: String?

    @State private var running = false

    var train: Train? {
        if let selectedTrain = selectedTrain {
            return layout.train(for: Identifier<Train>(uuid: selectedTrain))
        } else {
            return nil
        }
    }
    
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
            HStack {
                Picker("Locomotive:", selection: $selectedTrain) {
                    ForEach(layout.trains, id:\.self) { train in
                        Text(train.name).tag(train.id.uuid as String?)
                    }
                }
                .fixedSize()
            }
            .disabled(running)
            .padding([.leading, .trailing, .top])
                            
            Divider()

            if let train = train {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Steps to Measure:")
                        Button("Auto Select") {
                            updateSelectedSteps()
                        }
                        .disabled(running)
                    }
                    HStack {
                        TrainSpeedColumnView(selection: $selectedSpeedEntries, trainSpeed: train.speed)
                        TrainSpeedGraphView(trainSpeed: train.speed)
                    }
                    .frame(minHeight: 200)
                }
                .padding([.leading, .trailing])
            }

            Divider()
            
            HStack {
                TrainSpeedMeasureFeedbackView(document: document, layout: layout, label: "Feedback A", feedbackUUID: $feedbackA)
                
                TrainSpeedMeasureDistanceView(distance: $distanceAB)
                
                TrainSpeedMeasureFeedbackView(document: document, layout: layout, label: "Feedback B", feedbackUUID: $feedbackB)

                TrainSpeedMeasureDistanceView(distance: $distanceBC)
                
                TrainSpeedMeasureFeedbackView(document: document, layout: layout, label: "Feedback C", feedbackUUID: $feedbackC)
            }
            .disabled(running)
            .padding([.leading, .trailing])

            Divider()
            
            if let validationError = validationError {
                Text(validationError)
                    .padding([.leading, .trailing])
            } else {
                if let train = train, let feedbackA = feedbackA, let feedbackB = feedbackB, let feedbackC = feedbackC {
                    TrainSpeedMeasureControlsView(measurement: TrainSpeedMeasurement(layout: layout, interface: document.interface, train: train,
                                                                                     speedEntries: selectedSpeedEntries,
                                                                                     feedbackA: Identifier<Feedback>(uuid: feedbackA),
                                                                                     feedbackB: Identifier<Feedback>(uuid: feedbackB),
                                                                                     feedbackC: Identifier<Feedback>(uuid: feedbackC),
                                                                                     distanceAB: distanceAB,
                                                                                     distanceBC: distanceBC),
                                                  running: $running)
                        .padding([.leading, .trailing])
                }
            }

            OverviewRightPanelView(document: document, layout: document.layout)
        }
    }
    
    func updateSelectedSteps() {
        guard let train = train else {
            return
        }

        var steps: Set<TrainSpeed.SpeedTableEntry.ID> = [train.speed.speedTable[1].id]
        var index = 10
        while index < train.speed.speedTable.count {
            steps.insert(train.speed.speedTable[index].id)
            index += 10
        }
        steps.insert(train.speed.speedTable[train.speed.speedTable.count-1].id)
        selectedSpeedEntries = steps
    }
}

struct TrainSpeedMeasureFeedbackView: View {

    let document: LayoutDocument
    let layout: Layout
    let label: String
    
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
            Picker(label, selection: $feedbackUUID) {
                ForEach(layout.feedbacks, id:\.self) { feedback in
                    Text(feedback.name).tag(feedback.id.uuid as String?)
                }
            }
            .labelsHidden()
        }
    }
}

struct TrainSpeedMeasureDistanceView: View {

    @Binding var distance: Double

    var body: some View {
        VStack {
            Text("Distance")
            HStack {
                Text("􀅁")
                TextField("Distance:", value: $distance, format: .number)
                Text("cm 􀅂")
            }
        }
    }
}

struct TrainSpeedMeasureWizardView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutFCreator().newLayout())

    static var previews: some View {
        TrainSpeedMeasurementsView(document: doc, layout: doc.layout)
    }
}
