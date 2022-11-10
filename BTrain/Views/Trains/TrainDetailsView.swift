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

struct TrainDetailsGeometrySectionView: View {
    
    @ObservedObject var train: Train

    var body: some View {
        VStack {
            SectionTitleView(label: "Geometry")

            Form {
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

// TODO: move to be locomotive specific
struct TrainDetailsIconSectionView: View {
    
    @ObservedObject var loc: Locomotive
    @ObservedObject var locomotiveIconManager: LocomotiveIconManager

    var body: some View {
        VStack(alignment: .leading) {
            SectionTitleView(label: "Icon")

            HStack {
                ZStack {
                    TrainIconView(locomotiveIconManager: locomotiveIconManager, loc: loc, size: .large, hideIfNotDefined: false)
                    if locomotiveIconManager.icon(for: loc.id) == nil {
                        Text("Drag an Image")
                    }
                }
                
                if locomotiveIconManager.icon(for: loc.id) != nil {
                    Button("Remove") {
                        locomotiveIconManager.removeIconFor(loc: loc)
                    }
                }
            }.padding([.leading])
        }
    }
}

struct TrainDetailsView: View {
    
    let document: LayoutDocument
    @ObservedObject var train: Train

    var body: some View {
        VStack(alignment: .leading) {
            TrainDetailsGeometrySectionView(train: train)
            TrainDetailsReservationSectionView(train: train)
            TrainDetailsBlocksToAvoidSectionView(layout: document.layout, train: train)
            TrainDetailsTurnoutsToAvoidSectionView(layout: document.layout, train: train)
        }
    }
}

struct TrainEditView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutLoop1().newLayout())
    
    static var previews: some View {
        TrainDetailsView(document: doc, train: doc.layout.trains[0])
    }
}
