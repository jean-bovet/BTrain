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

/// This element defines a custom control point as defined by the user. By default a transition has two control points
/// that are automatically computed based on the source and target of the transition. However, if the user wants
/// to customize these control points of the Bezier curve, two ``ControlPoint`` are created for each transitions.
final class ControlPoint: Element, Codable {
    
    let id: Identifier<ControlPoint>
    
    /// The identifier of the transition this control point refers to.
    let transitionId: Identifier<Transition>
    
    /// The position of the control point
    var position: CGPoint
    
    internal init(id: Identifier<ControlPoint>, transitionId: Identifier<Transition>, position: CGPoint) {
        self.id = id
        self.transitionId = transitionId
        self.position = position
    }

    enum CodingKeys: CodingKey {
      case id, transitionId, position
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(Identifier<ControlPoint>.self, forKey: CodingKeys.id)
        let transitionId = try container.decode(Identifier<Transition>.self, forKey: CodingKeys.transitionId)
        let position = try container.decode(CGPoint.self, forKey: CodingKeys.position)
        self.init(id: id, transitionId: transitionId, position: position)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(transitionId, forKey: CodingKeys.transitionId)
        try container.encode(position, forKey: CodingKeys.position)
    }

}
