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

/// A provider that returns an ephemeral draggable shape
protocol EphemeralDragProvider {
    func draggableShape(at location: CGPoint) -> EphemeralDraggableShape?
}

/// A shape that exists only when dragged - for example when dragging a train from one block to another.
protocol EphemeralDraggableShape: DraggableShape {
    /// The information relative to the drag
    var dragInfo: EphemeralDragInfo? { get }

    /// Given an array of shapes, returns the shape that can be used as a drop target
    ///   - shapes: the array of shapes
    ///   - location: the location of the drop
    /// - Returns: a shape for the drop target or nil if no shape can be a drop target
    func droppableShape(_ shapes: [Shape], at location: CGPoint) -> Shape?
}

/// The information relative to the ephemeral drag operation
protocol EphemeralDragInfo {
    /// The shape being dragged. It will be rendered by the switchboard renderer as it is moved by the user.
    var shape: DraggableShape { get }

    /// The path that indicates the drop location, nil when there is no available drop location
    var dropPath: CGPath? { get set }

    /// The destination block for the drop
    var dropBlock: Block? { get set }
}
