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

/// Represents a block with an optional direction associated with it.
struct LayoutVector {
    let block: Block
    let direction: Direction?
    
    var entrySocket: Socket {
        switch direction {
        case .none:
            return block.any
            
        case .some(let wrapped):
            switch wrapped {
            case .previous:
                return block.next
            case .next:
                return block.previous
            }
        }
    }

    var exitSocket: Socket {
        switch direction {
        case .none:
            return block.any
            
        case .some(let wrapped):
            switch wrapped {
            case .previous:
                return block.previous
            case .next:
                return block.next
            }
        }
    }
    
}
