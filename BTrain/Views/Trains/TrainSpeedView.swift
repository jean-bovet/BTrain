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
    
    @ObservedObject var trainSpeed: TrainSpeed
    
    @State private var selection: TrainSpeed.SpeedTableEntry.ID?
    
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
            Canvas { context, size in
                let flipVertical: CGAffineTransform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: size.height)
                context.concatenate(flipVertical)
                context.stroke(speedPath(in: size), with: .color(.blue))
            }
        }.onAppear {
            trainSpeed.updateSpeedStepsTable()
        }
    }
}

struct TrainSpeedView_Previews: PreviewProvider {
    static var previews: some View {
        TrainSpeedView(trainSpeed: TrainSpeed(decoderType: .MFX))
    }
}
