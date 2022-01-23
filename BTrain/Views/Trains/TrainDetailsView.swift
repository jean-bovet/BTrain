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
                                
                Stepper("Trailing: \(train.numberOfTrailingReservedBlocks)", value: $train.numberOfTrailingReservedBlocks, in: 0...2)
            }.padding([.leading])
        }
    }
}

struct TrainDetailsSpeedSectionView: View {
    
    @ObservedObject var train: Train
    @State private var speedExpanded = false

    var body: some View {
        VStack {
            SectionTitleView(label: "Speed")

            Form {
                TextField("Max Speed:", value: $train.speed.maxSpeed,
                          format: .number)
                
                Button("Profile…") {
                    // TODO
                }
            }.padding([.leading])

//            DisclosureGroup("Speed", isExpanded: $speedExpanded) {
//                TrainSpeedView(trainSpeed: train.speed)
//                    .frame(height: 200)
//            }
        }
    }
}

struct TrainDetailsIconSectionView: View {
    
    @ObservedObject var train: Train
    let trainIconManager: TrainIconManager

    var body: some View {
        VStack(alignment: .leading) {
            SectionTitleView(label: "Icon")

            HStack {
                ZStack {
                    TrainIconView(trainIconManager: trainIconManager, train: train, size: .large)
                    if trainIconManager.imageFor(train: train) == nil {
                        Text("Drag an Image")
                    }
                }
                
                if trainIconManager.imageFor(train: train) != nil {
                    Button("Remove") {
                        // TODO
                    }
                }
            }.padding([.leading])
        }
    }
}

struct TrainDetailsView: View {
    
    let layout: Layout
    @ObservedObject var train: Train
    let trainIconManager: TrainIconManager

    var body: some View {
        VStack(alignment: .leading) {
            TrainDetailsDecoderSectionView(train: train)
            TrainDetailsGeometrySectionView(train: train)
            TrainDetailsReservationSectionView(train: train)
            TrainDetailsSpeedSectionView(train: train)
            TrainDetailsIconSectionView(train: train, trainIconManager: trainIconManager)
        }
    }
}

struct TrainEditView_Previews: PreviewProvider {
    
    static let layout = LayoutACreator().newLayout()
    
    static var previews: some View {
        TrainDetailsView(layout: layout, train: layout.trains[0],
                         trainIconManager: TrainIconManager(layout: layout))
            
    }
}
