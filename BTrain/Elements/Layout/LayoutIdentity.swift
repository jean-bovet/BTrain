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
import OrderedCollections

struct LayoutIdentity {
    
    enum LayoutIdentityPrefix: String {
        case block
        case station
        case turnout
        case feedback
        case transition
        case controlPoint
        case train
        case locomotive
        case route
        
        var prefix: String {
            switch self {
            case .block:
                return "b"
            case .station:
                return "s"
            case .turnout:
                return "t"
            case .feedback:
                return "f"
            case .transition:
                return "l"
            case .controlPoint:
                return "c"
            case .train:
                return "lw"
            case .locomotive:
                return "lc"
            case .route:
                return "r"
            }
        }
    }
    
    static func newIdentity<T>(_ elements: OrderedDictionary<Identifier<T>, T>, prefix: LayoutIdentityPrefix) -> Identifier<T> {
        var index = 1
        var id = Identifier<T>(uuid: "\(prefix.prefix)\(index)")
        while elements[id] != nil {
            index += 1
            id = Identifier<T>(uuid: "\(prefix.prefix)\(index)")
        }
        return id
    }
    
    static func newIdentity<T:ElementUUID>(_ elements: [T], prefix: LayoutIdentityPrefix) -> Identifier<T> {
        var index = 1
        var id = Identifier<T>(uuid: "\(prefix.prefix)\(index)")
        while elements.first(where: { $0.uuid == id.uuid }) != nil {
            index += 1
            id = Identifier<T>(uuid: "\(prefix.prefix)\(index)")
        }
        return id
    }
    
}
