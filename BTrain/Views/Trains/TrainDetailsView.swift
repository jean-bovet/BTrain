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
                Picker("Type:", selection: $train.decoder) {
                    ForEach(DecoderType.allCases, id:\.self) { proto in
                        Text(proto.rawValue).tag(proto as DecoderType)
                    }
                }.fixedSize()

                TextField("Address:", value: $train.address,
                          format: .number)
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
                TextField("Length (cm):", value: $train.length,
                          format: .number)
                
                TextField("Magnet Distance from Front (cm):", value: $train.magnetDistance,
                          format: .number)
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
                Stepper("Leading: \(train.maxNumberOfLeadingReservedBlocks)", value: $train.maxNumberOfLeadingReservedBlocks, in: 1...10)
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
                        Picker("Block:", selection: blockItem.blockId) {
                            ForEach(layout.blockMap.values, id:\.self) { block in
                                Text("\(block.name) — \(block.category.description)").tag(block.id as Identifier<Block>)
                            }
                        }.labelsHidden()
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
                        Picker("Turnout:", selection: turnoutItem.turnoutId) {
                            ForEach(layout.turnouts, id:\.self) { turnout in
                                Text("\(turnout.name)").tag(turnout.id as Identifier<Turnout>)
                            }
                        }.labelsHidden()
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
                Toggle("Inertia", isOn: $train.inertia)
                
                TextField("Max Speed:", value: $train.speed.maxSpeed,
                          format: .number)
                
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
                    if trainIconManager.imageFor(train: train) == nil {
                        Text("Drag an Image")
                    }
                }
                
                if trainIconManager.imageFor(train: train) != nil {
                    Button("Remove") {
                        trainIconManager.removeImageFor(train: train)
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
    
    static let doc = LayoutDocument(layout: LayoutACreator().newLayout())
    
    static var previews: some View {
        TrainDetailsView(document: doc, train: doc.layout.trains[0],
                         trainIconManager: TrainIconManager(layout: doc.layout))
            
    }
}
