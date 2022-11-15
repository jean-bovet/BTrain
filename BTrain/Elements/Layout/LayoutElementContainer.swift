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

protocol ElementCopying<E> {
    associatedtype E: Element
    func copy() -> E

    // TODO: move to its own protocol for more clarity?
    /// Allow for a default element to be created
    init()
}

protocol ElementNaming<E> {
    associatedtype E: Element
    var name: String { get set }
}

typealias LayoutElement<E> = Element & Codable & ElementCopying<E> & ElementNaming<E>

// TODO: add unit tests
/// Container capable of holding a map of elements and implementing the most common functions
/// expected by the layout
struct LayoutElementContainer<E: LayoutElement<E>> {
    
    private var elementsMap = OrderedDictionary<Identifier<E.ItemType>,E>()
    
    var elements: [E] {
        get {
            elementsMap.values.map {
                $0
            }
        }
        set {
            elementsMap.removeAll()
            newValue.forEach { elementsMap[$0.id] = $0 }
        }
    }
    
    subscript(index: Int) -> E {
      get {
          elements[index]
      }
     
      set(newValue) {
          elements[index] = newValue
      }
    }

    subscript(identifier: Identifier<E.ItemType>?) -> E? {
      get {
          if let identifier = identifier {
              return elementsMap[identifier]
          } else {
              return nil
          }
      }
     
      set(newValue) {
          if let identifier = identifier {
              elementsMap[identifier] = newValue
          }
      }
    }

    @discardableResult
    mutating func add(_ element: E) -> E {
        elementsMap[element.id] = element
        return element
    }

    @discardableResult
    mutating func duplicate(_ elementId: Identifier<E.ItemType>) -> E? {
        guard let existingElement = self[elementId] else {
            return nil
        }
        
        let newElement = existingElement.copy()
        return add(newElement)
    }
    
    mutating func remove(_ elementId: Identifier<E.ItemType>) {
        elementsMap.removeValue(forKey: elementId)
    }
    
    mutating func sort() {
        elements.sort {
            $0.name < $1.name
        }
    }

}

extension LayoutElementContainer: Codable {
    enum CodingKeys: CodingKey {
      case elements
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.elements = try container.decode([E].self, forKey: CodingKeys.elements)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(elements, forKey: CodingKeys.elements)
    }
}
