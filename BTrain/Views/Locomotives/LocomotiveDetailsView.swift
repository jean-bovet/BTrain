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
    @State private var showSpeedMeasureSheet = false

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
                                LocomotiveSpeedTimingFunctionView(tf: LocomotiveSpeedAcceleration(fromSteps: 0, toSteps: 100, timeIncrement: 0.1, stepIncrement: 4, type: type))
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
                    showSpeedMeasureSheet.toggle()
                }
            }.padding([.leading])
        }.sheet(isPresented: $showSpeedMeasureSheet) {
            LocomotiveSpeedMeasurementsView(document: document, layout: document.layout, loc: loc)
                .frame(idealWidth: sheetWidth, idealHeight: sheetHeight)
                .padding()
        }
    }
}

struct LocomotiveDetailsIconSectionView: View {
    
    @ObservedObject var loc: Locomotive
    @ObservedObject var locomotiveIconManager: LocomotiveIconManager

    var body: some View {
        VStack(alignment: .leading) {
            SectionTitleView(label: "Icon")

            HStack {
                ZStack {
                    LocomotiveIconView(locomotiveIconManager: locomotiveIconManager, loc: loc, size: .large, hideIfNotDefined: false)
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

struct LocomotiveDetailsView: View {
    
    let document: LayoutDocument
    @ObservedObject var loc: Locomotive

    var body: some View {
        VStack(alignment: .leading) {
            LocDetailsDecoderSectionView(loc: loc)
            LocDetailsGeometrySectionView(loc: loc)
            LocDetailsSpeedSectionView(document: document, loc: loc)
            LocomotiveDetailsIconSectionView(loc: loc, locomotiveIconManager: document.locomotiveIconManager)
        }
    }
}

struct LocomotiveDetailsView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutLoop1().newLayout())

    static var previews: some View {
        LocomotiveDetailsView(document: doc, loc: doc.layout.locomotives[0])
    }
}
