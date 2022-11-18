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

struct TurnoutShapeView: View {
    let layout: Layout
    let category: Turnout.Category
    let requestedState: Turnout.State
    let actualState: Turnout.State
    let shapeContext: ShapeContext

    /// True if a reservation should be used to simulate how a specific branch of
    /// the turnout is highlighted to show the path of the reservation.
    let reservation: Bool

    var name: String = ""
    var rotation: Double = 0

    let viewSize = CGSize(width: 64, height: 34 * 2)

    var turnout: Turnout {
        let t = Turnout()
        t.name = name
        t.category = category
        t.requestedState = requestedState
        t.actualState = actualState
        t.center = .init(x: viewSize.width / 2, y: viewSize.height / 2)
        t.rotationAngle = rotation

        if reservation {
            let sockets = Turnout.sockets(forState: requestedState, category: category)
            if sockets.count == 2 {
                // Initialize the reservation using the sockets that are available
                // given the category and state of the turnout.
                t.reserved = .init(train: .init(uuid: "t1"), sockets: .init(fromSocketId: sockets[0], toSocketId: sockets[1]))
            }
        }
        return t
    }

    var shape: TurnoutShape {
        let shape = TurnoutShape(layoutController: nil, layout: layout, turnout: turnout, shapeContext: shapeContext)
        return shape
    }

    var body: some View {
        Canvas { context, _ in
            context.withCGContext { context in
                shape.draw(ctx: context)
            }
        }.frame(width: viewSize.width, height: viewSize.height)
    }
}

struct TurnoutShapeView_Previews: PreviewProvider {
    static let layout = LayoutLoop1().newLayout()
    static let context = ShapeContext()

    static var previews: some View {
        VStack(alignment: .leading) {
            ForEach(Turnout.Category.allCases, id: \.self) { category in
                HStack {
                    ForEach(Turnout.states(for: category)) { state in
                        VStack {
                            Text(category.rawValue)
                            Text(state.rawValue)
                        }

                        VStack {
                            TurnoutShapeView(layout: layout, category: category, requestedState: state, actualState: Turnout.defaultState(for: category), shapeContext: context, reservation: true)
                            if state != Turnout.defaultState(for: category) {
                                TurnoutShapeView(layout: layout, category: category, requestedState: state, actualState: state, shapeContext: context, reservation: true)
                            }
                        }
                    }
                }
            }
        }
    }
}
