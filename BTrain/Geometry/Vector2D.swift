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

// Source: https://en.wikipedia.org/wiki/Dot_product#Geometric_definition

struct Vector2D {
    let x: Double
    let y: Double
}

infix operator • : MultiplicationPrecedence

extension Vector2D {
    
    static func • (left: Vector2D, right: Vector2D) -> Double {
        left.x * right.x + left.y * right.y
    }
    
    var magnitude: Double {
        sqrt(x * x + y * y)
    }

    var normalized: Vector2D {
        Vector2D(x: x / magnitude, y: y / magnitude)
    }

    func angle(to vector: Vector2D) -> Double {
        acos(normalized • vector.normalized)
    }
    
    static func cross(left: Vector2D, right: Vector2D) -> Double {
        left.x * right.y - left.y * right.x
    }

}
