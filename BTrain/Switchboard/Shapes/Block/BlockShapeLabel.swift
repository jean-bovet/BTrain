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

import Foundation
import CoreGraphics

/// Defines a label displayed by the block shape. It is used to display
/// for example the name of the block, the name of the train or the train icons.
protocol BlockShapeLabel {
    
    /// True if the label is hidden
    var hidden: Bool { get }
    
    /// The size of the label
    var size: CGSize { get }
        
    /// Draw the labels at the specified coordinates
    /// - Parameters:
    ///   - anchor: the anchor where to start drawing the label
    ///   - rotation: the rotation angle of the label
    ///   - rotationCenter: the rotation center of the label
    /// - Returns: an optional path representing the content that was drawn
    func draw(at anchor: CGPoint, rotation: CGFloat, rotationCenter: CGPoint) -> BlockShapeLabelPath?
}

/// Defines the path of a label which can be used to interrogate the path for selection purpose
struct BlockShapeLabelPath {
    let path: CGPath
    let transform: CGAffineTransform
    
    /// Returns true if the point is inside the path
    /// - Parameter point: the point
    /// - Returns: true if the point is inside the path, false otherwise
    func inside(_ point: CGPoint) -> Bool {
        path.contains(point, transform: transform)
    }
}
