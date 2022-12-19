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

// A path consists of an array of elements.
struct GraphPath: Equatable {
    let elements: [GraphPathElement]

    var count: Int {
        elements.count
    }

    var isEmpty: Bool {
        count == 0
    }

    var toStrings: [String] {
        elements.map(\.description)
    }

    static func empty() -> GraphPath {
        .init([])
    }

    init(_ elements: [GraphPathElement]) {
        self.elements = elements
    }

    init(_ element: GraphPathElement) {
        self.init([element])
    }

    init(_ elements: ArraySlice<GraphPathElement>) {
        self.init(Array(elements))
    }

    func contains(_ element: GraphPathElement) -> Bool {
        elements.contains(element)
    }

    static func + (lhs: GraphPath, rhs: GraphPath) -> GraphPath {
        GraphPath(lhs.elements + rhs.elements)
    }

    static func + (lhs: GraphPath, rhs: GraphPathElement) -> GraphPath {
        GraphPath(lhs.elements + [rhs])
    }

    static func == (lhs: GraphPath, rhs: GraphPath) -> Bool {
        lhs.elements == rhs.elements
    }
}
