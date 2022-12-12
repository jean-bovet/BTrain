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
import Combine

/// Property wrapper that simplifies the management of a reference to an element identifier
/// while also having the element instance available.
///
/// All references to an element (aka Block, Train, etc) should use the element identifier (aka Identifier<Element>)
/// instead of the element instance, in order for serialization to be possible and to avoid retain cycle.
///
/// However, it is useful to also have access to the element instance itself to simplify the code which this property
/// wrapper makes possible.
@propertyWrapper struct ElementProperty<E:LayoutElement> {
    
    private var publisher = PassthroughSubject<E?, Never>()

    var projectedValue: AnyPublisher<E?, Never> {
        return self.publisher.eraseToAnyPublisher()
    }

    var elementId: Identifier<E.ItemType>?
    
    var wrappedValue: E? {
        willSet {
            publisher.send(newValue)
        }
        didSet {
            elementId = wrappedValue?.id
        }
    }
    
    init(wrappedValue: E?) {
        self.wrappedValue = wrappedValue
    }
    
    /// Restores the element instance using the specified container and the underlying elementId
    /// defined in this wrapper. This method must be called once after deserialization.
    /// - Parameter container: the container
    mutating func restore(_ container: LayoutElementContainer<E>) {
        assert(wrappedValue == nil)
        wrappedValue = container[elementId]
        assert(wrappedValue?.id == elementId)
    }
}
