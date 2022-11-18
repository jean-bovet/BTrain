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

struct LocomotiveSpeedTimingFunctionView: View {
    let tf: LocomotiveSpeedAcceleration

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Canvas { context, size in
            let transform = CGAffineTransform.identity
                .translatedBy(x: 0.0, y: size.height)
                .scaledBy(x: 1.0, y: -1.0)

            context.transform = transform

            context.withCGContext { cg in
                cg.move(to: .zero)
                let deltaX = size.width / tf.totalDuration
                let deltaY = size.height / abs(CGFloat(tf.toSteps - tf.fromSteps))
                for t in stride(from: 0, to: tf.totalDuration + tf.timeIncrement, by: tf.timeIncrement) {
                    cg.addLine(to: CGPoint(x: t * deltaX, y: Double(tf.stepValue(at: t)) * deltaY))
                }
                if colorScheme == .dark {
                    cg.setStrokeColor(NSColor.lightGray.cgColor)
                } else {
                    cg.setStrokeColor(NSColor.black.cgColor)
                }
                cg.strokePath()
            }
        }
    }
}

struct LocomotiveSpeedTimingFunctionView_Previews: PreviewProvider {
    static var previews: some View {
        LocomotiveSpeedTimingFunctionView(tf: LocomotiveSpeedAcceleration(fromSteps: 0, toSteps: 100, timeIncrement: 0.1, stepIncrement: 4, type: .linear))
        LocomotiveSpeedTimingFunctionView(tf: LocomotiveSpeedAcceleration(fromSteps: 0, toSteps: 100, timeIncrement: 0.1, stepIncrement: 4, type: .bezier))
    }
}
