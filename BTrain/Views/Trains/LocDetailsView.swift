//
//  LocDetailsView.swift
//  BTrain
//
//  Created by Jean Bovet on 11/8/22.
//

import SwiftUI

struct LocDetailsDecoderSectionView: View {
    
    @ObservedObject var loc: Locomotive

    var body: some View {
        VStack {
            SectionTitleView(label: "Decoder")

            Form {
                UndoProvider($loc.decoder) { value in
                    Picker("Type:", selection: value) {
                        ForEach(DecoderType.allCases, id:\.self) { proto in
                            Text(proto.rawValue).tag(proto as DecoderType)
                        }
                    }.fixedSize()
                }

                UndoProvider($loc.address) { value in
                    TextField("Address:", value: value, format: .number)
                }
            }.padding([.leading])
        }
    }
}

struct LocDetailsGeometrySectionView: View {
    
    @ObservedObject var loc: Locomotive

    var body: some View {
        VStack {
            SectionTitleView(label: "Geometry")

            Form {
                UndoProvider($loc.length) { value in
                    TextField("Locomotive:", value: value, format: .number)
                        .unitStyle("cm")
                }                
            }.padding([.leading])
        }
    }
}

struct LocDetailsSpeedSectionView: View {
    
    let document: LayoutDocument

    @ObservedObject var loc: Locomotive
    
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
                UndoProvider($loc.speed.accelerationProfile) { acceleration in
                    Picker("Acceleration:", selection: acceleration) {
                        ForEach(LocomotiveSpeedAcceleration.Acceleration.allCases, id: \.self) { type in
                            HStack {
                                Text("\(type.description)")
                                TrainSpeedTimingFunctionView(tf: LocomotiveSpeedAcceleration(fromSteps: 0, toSteps: 100, timeIncrement: 0.1, stepIncrement: 4, type: type))
                                    .frame(width: 100, height: 50)
                            }
                        }
                    }
                }

                UndoProvider($loc.speed.maxSpeed) { maxSpeed in
                    TextField("Max Speed:", value: maxSpeed, format: .number)
                        .unitStyle("kph")
                }

                UndoProvider($loc.speed.accelerationStepSize) { stepSize in
                    TextField("Step Size:", value: stepSize, format: .number,
                              prompt: Text("\(LocomotiveSpeedManager.DefaultStepSize)"))
                        .unitStyle("step")
                }

                UndoProvider($loc.speed.accelerationStepDelay) { stepDelay in
                    TextField("Step Delay:", value: stepDelay, format: .number,
                              prompt: Text("\(LocomotiveSpeedManager.DefaultStepDelay)"))
                        .unitStyle("ms")
                }

                UndoProvider($loc.speed.stopSettleDelay) { stopSettleDelay in
                    TextField("Stop Settle Delay:", value: stopSettleDelay, format: .number)
                        .unitStyle("sec.")
                        .help("Delay until the locomotive is effectively considered fully stopped after a speed of 0 has been sent to the Digital Controller")
                }

                Button("Profile…") {
                    showSpeedProfileSheet.toggle()
                }
            }.padding([.leading])
        }.sheet(isPresented: $showSpeedProfileSheet) {
            TrainSpeedView(document: document, loc: loc, trainSpeed: loc.speed)
                .frame(idealWidth: sheetWidth, idealHeight: sheetHeight)
                .padding()
        }
    }
}

struct LocDetailsView: View {
    
    let document: LayoutDocument
    @ObservedObject var loc: Locomotive

    var body: some View {
        VStack(alignment: .leading) {
            LocDetailsDecoderSectionView(loc: loc)
            LocDetailsGeometrySectionView(loc: loc)
            LocDetailsSpeedSectionView(document: document, loc: loc)
            TrainDetailsIconSectionView(loc: loc, locomotiveIconManager: document.locomotiveIconManager)
        }
    }
}

struct LocDetailsView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutLoop1().newLayout())

    static var previews: some View {
        LocDetailsView(document: doc, loc: doc.layout.locomotives[0])
    }
}
