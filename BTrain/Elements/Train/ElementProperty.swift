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

import Combine
import Foundation

/// Property wrapper that simplifies the management of a reference to an element identifier
/// while also having the element instance available.
///
/// All references to an element (aka Block, Train, etc) should use the element identifier (aka Identifier<Element>)
/// instead of the element instance, in order for serialization to be possible and to avoid retain cycle.
///
/// However, it is useful to also have access to the element instance itself to simplify the code which this property
/// wrapper makes possible.
@propertyWrapper struct ElementProperty<E: LayoutElement & AnyObject> {
    /// We need to use this static subscript in order to get a hold of the enclosing
    /// instance of this property wrapper to inform it of any changes to the
    /// stored value of this wrapper.
    /// See [this blog](https://www.swiftbysundell.com/articles/accessing-a-swift-property-wrappers-enclosing-instance/)
    static subscript<T: ObservableObject>(
        _enclosingInstance instance: T,
        wrapped _: ReferenceWritableKeyPath<T, E?>,
        storage storageKeyPath: ReferenceWritableKeyPath<T, Self>
    ) -> E? {
        get {
            instance[keyPath: storageKeyPath].storage?.value
        }
        set {
            // Notify the enclosing instance's publisher of the change
            if let publisher = instance.objectWillChange as? ObservableObjectPublisher {
                publisher.send()
            }

            // Notify the publisher of the property wrapper itself of the change
            instance[keyPath: storageKeyPath].publisher.send(newValue)

            if let newValue = newValue {
                instance[keyPath: storageKeyPath].storage = .init(newValue)
            } else {
                instance[keyPath: storageKeyPath].storage = nil
            }
        }
    }

    var elementId: Identifier<E.ItemType>?

    private var storage: WeakObject<E>? {
        didSet {
            elementId = storage?.value?.id
        }
    }

    @available(*, unavailable,
               message: "@Published can only be applied to classes")
    var wrappedValue: E? {
        get { fatalError() }
        set { fatalError() }
    }

    private var publisher = PassthroughSubject<E?, Never>()

    var projectedValue: AnyPublisher<E?, Never> {
        self.publisher.eraseToAnyPublisher()
    }

    /// Restores the element instance using the specified container and the underlying elementId
    /// defined in this wrapper. This method must be called once after deserialization.
    /// - Parameter container: the container
    mutating func restore(_ container: LayoutElementContainer<E>) {
        assert(storage == nil)
        if let elementId = elementId, let element = container[elementId] {
            storage = .init(element)
        } else {
            storage = nil
        }
        assert(storage?.value?.id == elementId)
    }
}

/// Object referencing another object with weak reference
final class WeakObject<T: AnyObject> {
    private(set) weak var value: T?
    init(_ v: T) { value = v }
}
