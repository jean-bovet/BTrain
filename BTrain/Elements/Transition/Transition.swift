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

// A transition is a virtual link between two elements (turnouts or blocks).
// Note that the transition does not have any particular direction, it simply
// identify the connection between two element "a" and "b".
//
//
//  Socket A                     Socket B
//    │                             │
//    │                             │
//    ▼          Transition         ▼
//    ○─────────────────────────────○
class Transition: Element, Codable, CustomStringConvertible {
    let id: Identifier<Transition>

    // Socket to the first element
    var a: Socket

    // Socket to the second element
    var b: Socket

    // Contains the train that has reserved this transition,
    // or nil if no train has reserved it.
    var reserved: Identifier<Train>?

    // The identifier of the train located inside this transition
    var train: Identifier<Train>?

    /// Returns this transition but with socket a and b inverted. The returned class
    /// is a proxy to this one so any changes made to the proxy will be reflected in this class.
    var reverse: TransitionInverse {
        TransitionInverse(transition: self)
    }

    var description: String {
        "\(a) -> \(b)"
    }

    func description(_ layout: Layout) -> String {
        "\(a.description(layout)) -> \(b.description(layout))"
    }
    
    required init(id: Identifier<Transition>, a: Socket, b: Socket) {
        self.id = id
        self.a = a
        self.b = b
    }

    convenience init(id: String, a: Socket, b: Socket) {
        self.init(id: Identifier(uuid: id), a: a, b: b)
    }

    // Returns true if a transition is the same as another one.
    // A transition is considered the same if it links the same two elements.
    func same(as t: Transition) -> Bool {
        a.contains(other: t.a) && b.contains(other: t.b) ||
            a.contains(other: t.b) && b.contains(other: t.a)
    }

    // MARK: Codable

    enum CodingKeys: CodingKey {
        case id, from, to, reserved, train
    }

    required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(Identifier<Transition>.self, forKey: CodingKeys.id)
        let a = try container.decode(Socket.self, forKey: CodingKeys.from)
        let b = try container.decode(Socket.self, forKey: CodingKeys.to)
        self.init(id: id, a: a, b: b)
        reserved = try container.decodeIfPresent(Identifier<Train>.self, forKey: CodingKeys.reserved)
        train = try container.decodeIfPresent(Identifier<Train>.self, forKey: CodingKeys.train)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(a, forKey: CodingKeys.from)
        try container.encode(b, forKey: CodingKeys.to)
        try container.encode(reserved, forKey: CodingKeys.reserved)
        try container.encode(train, forKey: CodingKeys.train)
    }
}

extension Transition: Restorable {
    func restore(layout _: Layout) {
        if train == nil {
            // Do not restore the reservation if the train does not belong to this transition.
            // We do not want the user to see reservation upon opening a new document because
            // the train is not actively running anymore.
            reserved = nil
        }
    }
}

// Because a transition is represented by two sockets, `a` and `b`, the code must
// always check both ordering to make sure a transition exists between two elements.
//
// For example, a transition between "Block 1" and "Block 2" can be represented in two ways:
// 1)
//        Socket A        Socket B
//           │               │
//           │               │
// ┌─────────┐▼               ▼┌─────────┐
// │ Block 1 │○───────────────○│ Block 2 │
// └─────────┘                 └─────────┘
//
//
// 2)
//        Socket B        Socket A
//           │               │
//           │               │
// ┌─────────┐▼               ▼┌─────────┐
// │ Block 1 │○───────────────○│ Block 2 │
// └─────────┘                 └─────────┘
//
// In practice, this means testing both ordering in this way:
// if transition.a == block1.nextSocket && transition.b = block2.previousSocket
//    || transition.b == block1.nextSocket && transition.a == block2.previousSocket
//
// To simplify the code, we always return a transition and its "inverse", which is
// the same transition but with socket `a` and `b` swapped. That way, the code can
// be simplified to only use one set of sockets:
// if transition.a == block1.nextSocket && transition.b = block2.previousSocket
final class TransitionInverse: Transition {
    let transition: Transition

    override var description: String {
        "\(a) -> \(b)"
    }

    override var a: Socket {
        get {
            transition.b
        }
        set {
            transition.b = newValue
        }
    }

    override var b: Socket {
        get {
            transition.a
        }
        set {
            transition.a = newValue
        }
    }

    override var reserved: Identifier<Train>? {
        get {
            transition.reserved
        }
        set {
            transition.reserved = newValue
        }
    }

    override var train: Identifier<Train>? {
        get {
            transition.train
        }
        set {
            transition.train = newValue
        }
    }

    init(transition: Transition) {
        self.transition = transition
        super.init(id: transition.id, a: transition.a, b: transition.b)
    }

    required init(id _: Identifier<Transition>, a _: Socket, b _: Socket) {
        fatalError("init(id:a:b:) is not supported for inverse transition")
    }
}
