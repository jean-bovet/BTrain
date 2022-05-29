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

// Describes a unique identifier for each element of the layout
struct Identifier<T>: Codable, Comparable, Hashable, CustomStringConvertible, ElementUUID {
    let uuid: String
    
    var description: String {
        uuid
    }
    
    static func < (lhs: Identifier<T>, rhs: Identifier<T>) -> Bool {
        lhs.uuid < rhs.uuid
    }
    
}

protocol ElementUUID {
    var uuid: String { get }
}

// Describes an element of the layout
protocol Element: ElementUUID, Hashable, Identifiable, Comparable, CustomStringConvertible {
    associatedtype ItemType
    var id: Identifier<ItemType> { get }
}

extension Element {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
    
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.id < rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var uuid: String {
        id.uuid
    }
    
    var description: String {
        id.description
    }

}
