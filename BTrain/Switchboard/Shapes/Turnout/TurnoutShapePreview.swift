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

struct TurnoutShapePreview: View {
    let layout = Layout()
    let context: ShapeContext = {
        let c = ShapeContext()
        c.showTurnoutName = true
        return c
    }()

    var body: some View {
        VStack {
            ForEach(Turnout.Category.allCases, id: \.self) { category in
                HStack {
                    ForEach(0 ..< 8) { index in
                        TurnoutShapeView(layout: layout,
                                         category: category,
                                         requestedState: Turnout.states(for: category)[0],
                                         actualState: Turnout.states(for: category)[1],
                                         shapeContext: context, reservation: false,
                                         name: "foo",
                                         rotation: .pi / 4 * Double(index))
                    }
                }
            }
        }
    }
}

struct TurnoutShapePreview_Previews: PreviewProvider {
    static var previews: some View {
        TurnoutShapePreview()
    }
}
