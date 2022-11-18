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

import CoreGraphics
import Foundation

protocol Shape: AnyObject {
    var identifier: String { get }

    var visible: Bool { get }

    var selected: Bool { get set }

    var bounds: CGRect { get }

    func draw(ctx: CGContext)

    func inside(_ point: CGPoint) -> Bool
}

protocol ActionableShape: Shape {
    func performAction(at location: CGPoint) -> Bool
}

protocol DraggableShape: Shape {
    var center: CGPoint { get set }
}

protocol RotableShape: Shape {
    var rotationCenter: CGPoint { get }

    var rotationAngle: CGFloat { get set }

    var rotationPoint: CGPoint { get }

    var rotationHandle: CGPath { get }
}
