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

struct TrainDetailsDecoderSectionView: View {
    
    @ObservedObject var train: Train

    var body: some View {
        VStack {
            SectionTitleView(label: "Decoder")

            Form {
                UndoProvider($train.decoder) { value in
                    Picker("Type:", selection: value) {
                        ForEach(DecoderType.allCases, id:\.self) { proto in
                            Text(proto.rawValue).tag(proto as DecoderType)
                        }
                    }.fixedSize()
                }

                UndoProvider($train.address) { value in
                    TextField("Address:", value: value, format: .number)
                }
            }.padding([.leading])
        }
    }
}

struct TrainDetailsGeometrySectionView: View {
    
    @ObservedObject var train: Train

    var body: some View {
        VStack {
            SectionTitleView(label: "Geometry")

            Form {
                UndoProvider($train.locomotiveLength) { value in
                    TextField("Locomotive:", value: value, format: .number)
                        .unitStyle("cm")
                }
                
                UndoProvider($train.wagonsLength) { value in
                    TextField("Wagons:", value: value, format: .number)
                        .unitStyle("cm")
                }
            }.padding([.leading])
        }
    }
}

struct TrainDetailsReservationSectionView: View {
    
    @ObservedObject var train: Train

    var body: some View {
        VStack(alignment: .leading) {
            SectionTitleView(label: "Reservation")

            Form {
                UndoProvider($train.maxNumberOfLeadingReservedBlocks) { value in
                    Stepper("Leading: \(train.maxNumberOfLeadingReservedBlocks)", value: value, in: 1...10)
                }
            }.padding([.leading])
        }
    }
}

struct TrainDetailsBlocksToAvoidSectionView: View {
    
    let layout: Layout
    @ObservedObject var train: Train

    var body: some View {
        VStack(alignment: .leading) {
            SectionTitleView(label: "Blocks To Avoid")

            List {
                ForEach($train.blocksToAvoid, id: \.self) { blockItem in
                    HStack {
                        UndoProvider(blockItem.blockId) { value in
                            Picker("Block:", selection: value) {
                                ForEach(layout.blockMap.values, id:\.self) { block in
                                    Text("\(block.name) — \(block.category.description)").tag(block.id as Identifier<Block>)
                                }
                            }.labelsHidden()
                        }
                        Spacer()
                        Button("-") {
                            train.blocksToAvoid.removeAll(where: { $0.id == blockItem.id })
                        }
                    }
                }
            }.frame(minHeight: 100)
            
            Button("+") {
                train.blocksToAvoid.append(.init(layout.blockIds.first!))
            }.disabled(layout.blockIds.isEmpty)
        }
    }
}

struct TrainDetailsTurnoutsToAvoidSectionView: View {
    
    let layout: Layout
    @ObservedObject var train: Train

    var body: some View {
        VStack(alignment: .leading) {
            SectionTitleView(label: "Turnouts To Avoid")

            List {
                ForEach($train.turnoutsToAvoid, id: \.self) { turnoutItem in
                    HStack {
                        UndoProvider(turnoutItem.turnoutId) { value in
                            Picker("Turnout:", selection: value) {
                                ForEach(layout.turnouts, id:\.self) { turnout in
                                    Text("\(turnout.name)").tag(turnout.id as Identifier<Turnout>)
                                }
                            }.labelsHidden()
                        }
                        Spacer()
                        Button("-") {
                            train.turnoutsToAvoid.removeAll(where: { $0.id == turnoutItem.id })
                        }
                    }
                }
            }.frame(minHeight: 100)
            
            Button("+") {
                train.turnoutsToAvoid.append(.init(layout.turnouts.first!.id))
            }.disabled(layout.turnouts.isEmpty)
        }
    }
}

struct TrainDetailsSpeedSectionView: View {
    
    let document: LayoutDocument

    @ObservedObject var train: Train
    
    @State private var speedExpanded = false
    @State private var showSpeedProfileSheet = false
    
    var sheetWidth: Double {
        if let screen = NSScreen.main {
            return screen.visibleFrame.width * 0.6
        } else {
            return 800
        }
    }

    var sheetHeight: Double {
        if let screen = NSScreen.main {
            return screen.visibleFrame.height * 0.6
        } else {
            return 600
        }
    }

    var body: some View {
        VStack {
            SectionTitleView(label: "Speed")

            Form {
                UndoProvider($train.speed.accelerationProfile) { acceleration in
                    Picker("Acceleration:", selection: acceleration) {
                        ForEach(TrainSpeedAcceleration.Acceleration.allCases, id: \.self) { type in
                            HStack {
                                Text("\(type.description)")
                                TrainSpeedTimingFunctionView(tf: TrainSpeedAcceleration(fromSteps: 0, toSteps: 100, timeIncrement: 0.1, stepIncrement: 4, type: type))
                                    .frame(width: 100, height: 50)
                            }
                        }
                    }
                }

                UndoProvider($train.speed.maxSpeed) { maxSpeed in
                    TextField("Max Speed:", value: maxSpeed, format: .number)
                        .unitStyle("kph")
                }

                UndoProvider($train.speed.accelerationStepSize) { stepSize in
                    TextField("Step Size:", value: stepSize, format: .number,
                              prompt: Text("\(TrainSpeedManager.DefaultStepSize)"))
                        .unitStyle("step")
                }

                UndoProvider($train.speed.accelerationStepDelay) { stepDelay in
                    TextField("Step Delay:", value: stepDelay, format: .number,
                              prompt: Text("\(TrainSpeedManager.DefaultStepDelay)"))
                        .unitStyle("ms")
                }

                UndoProvider($train.speed.stopSettleDelay) { stopSettleDelay in
                    TextField("Stop Settle Delay:", value: stopSettleDelay, format: .number)
                        .unitStyle("sec.")
                        .help("Delay until the locomotive is effectively considered fully stopped after a speed of 0 has been sent to the Digital Controller")
                }

                Button("Profile…") {
                    showSpeedProfileSheet.toggle()
                }
            }.padding([.leading])
        }.sheet(isPresented: $showSpeedProfileSheet) {
            TrainSpeedView(document: document, train: train, trainSpeed: train.speed)
                .frame(idealWidth: sheetWidth, idealHeight: sheetHeight)
                .padding()
        }
    }
}

struct TrainDetailsIconSectionView: View {
    
    @ObservedObject var train: Train
    @ObservedObject var trainIconManager: TrainIconManager

    var body: some View {
        VStack(alignment: .leading) {
            SectionTitleView(label: "Icon")

            HStack {
                ZStack {
                    TrainIconView(trainIconManager: trainIconManager, train: train, size: .large, hideIfNotDefined: false)
                    if trainIconManager.icon(for: train.id) == nil {
                        Text("Drag an Image")
                    }
                }
                
                if trainIconManager.icon(for: train.id) != nil {
                    Button("Remove") {
                        trainIconManager.removeIconFor(train: train)
                    }
                }
            }.padding([.leading])
        }
    }
}

struct TrainDetailsView: View {
    
    let document: LayoutDocument
    @ObservedObject var train: Train
    let trainIconManager: TrainIconManager

    var body: some View {
        VStack(alignment: .leading) {
            TrainDetailsDecoderSectionView(train: train)
            TrainDetailsGeometrySectionView(train: train)
            TrainDetailsReservationSectionView(train: train)
            TrainDetailsBlocksToAvoidSectionView(layout: document.layout, train: train)
            TrainDetailsTurnoutsToAvoidSectionView(layout: document.layout, train: train)
            TrainDetailsSpeedSectionView(document: document, train: train)
            TrainDetailsIconSectionView(train: train, trainIconManager: trainIconManager)
        }
    }
}

struct TrainEditView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutLoop1().newLayout())
    
    static var previews: some View {
        TrainDetailsView(document: doc, train: doc.layout.trains[0],
                         trainIconManager: TrainIconManager())
            
    }
}
