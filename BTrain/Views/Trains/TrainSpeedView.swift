//
//  TrainSpeedView.swift
//  BTrain
//
//  Created by Jean Bovet on 1/9/22.
//

import SwiftUI

struct TrainSpeedView: View {
    
    @ObservedObject var trainSpeed: TrainSpeed
    
    @State private var selection: TrainSpeed.SpeedStep.ID?
    
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
                    Text("\(steps.steps.wrappedValue)")
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
        TrainSpeedView(trainSpeed: TrainSpeed())
    }
}
