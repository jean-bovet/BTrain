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

struct LocomotiveSpeedGraphView: View {
    @ObservedObject var trainSpeed: LocomotiveSpeed
    @Environment(\.colorScheme) var colorScheme

    let fontSize = NSFont.systemFontSize
    let margin = NSFont.systemFontSize / 2

    var textColor: CGColor {
        colorScheme == .dark ? .white : .black
    }

    func maxSpeed() -> Int {
        var speed = 0
        for entry in trainSpeed.speedTable {
            if let sp = entry.speed {
                speed = max(speed, Int(sp))
            }
        }
        return speed
    }

    func drawChart(in rect: CGRect, ctx: CGContext) {
        let maxY = maxSpeed()
        let (_, vAxisTextRect) = ctx.prepareText(text: "\(maxY)", color: .black, fontSize: fontSize)

        let maxX = trainSpeed.speedTable.count
        let (_, hAxisTextRect) = ctx.prepareText(text: "\(maxX)", color: .black, fontSize: fontSize)

        let xOffset = vAxisTextRect.width
        let yOffset = hAxisTextRect.height

        let gRect = CGRect(x: rect.origin.x + xOffset, y: rect.origin.y + yOffset, width: rect.width - xOffset, height: rect.height - yOffset)

        // Draw X-Axis
        ctx.setStrokeColor(.init(gray: 0.5, alpha: 0.5))
        for index in 0 ... maxX {
            if index % 10 == 0 {
                let x = gRect.origin.x + Double(gRect.width) / Double(maxX) * Double(index)
                let y = gRect.origin.y
                ctx.move(to: CGPoint(x: x, y: y))
                ctx.addLine(to: CGPoint(x: x, y: y + rect.height))
                ctx.strokePath()

                ctx.drawText(at: CGPoint(x: x, y: y - fontSize), vAlignment: .bottom, hAlignment: .center, flip: false, text: "\(index)", color: textColor, fontSize: fontSize)
            }
        }

        // Draw Y-Axis
        ctx.setStrokeColor(.init(gray: 0.5, alpha: 0.5))
        for index in 0 ... maxY {
            if index % 20 == 0 {
                let x = gRect.origin.x
                let y = gRect.origin.y + Double(gRect.height) / Double(maxY) * Double(index)
                ctx.move(to: CGPoint(x: x, y: y))
                ctx.addLine(to: CGPoint(x: rect.width, y: y))
                ctx.strokePath()

                ctx.drawText(at: CGPoint(x: vAxisTextRect.width, y: y - fontSize / 2), hAlignment: .right, flip: false, text: "\(index)", color: textColor, fontSize: fontSize)
            }
        }

        // Draw line
        ctx.move(to: gRect.origin)
        for (index, speed) in trainSpeed.speedTable.enumerated() {
            if let speedValue = speed.speed {
                let x = gRect.origin.x + Double(index) / Double(maxX) * gRect.width
                let y = gRect.origin.y + Double(speedValue) / Double(maxY) * gRect.height
                let point = CGPoint(x: x, y: y)
                ctx.addLine(to: point)
            }
        }
        ctx.setStrokeColor(.init(red: 0, green: 0, blue: 1.0, alpha: 1.0))
        ctx.setLineWidth(2.0)
        ctx.strokePath()
    }

    var body: some View {
        Canvas { context, size in
            let flipVertical: CGAffineTransform = .init(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: size.height)
            context.concatenate(flipVertical)

            let rect = CGRect(x: margin, y: margin, width: size.width - 2 * margin, height: size.height - 2 * margin)
            context.withCGContext { ctx in
                drawChart(in: rect, ctx: ctx)
            }
        }
    }
}

struct TrainSpeedGraphView_Previews: PreviewProvider {
    static let doc = LayoutDocument(layout: LayoutComplex().newLayout())

    static var previews: some View {
        LocomotiveSpeedGraphView(trainSpeed: doc.layout.locomotives[0].speed)
    }
}
