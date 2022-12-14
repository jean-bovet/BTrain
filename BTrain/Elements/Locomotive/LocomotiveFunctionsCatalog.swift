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

import AppKit

/// Manages the mapping of all the available functions to their attributes.
///
/// This catalog is persisted with the document in order to restore the locomotive functions,
/// include their icons, when the document is not connected to the Digital Controller.
final class LocomotiveFunctionsCatalog {
    
    struct AttributesCache: Codable {
        
        /// Cache of the global attributes of the CS3
        var globalAttributes = [UInt32:CommandLocomotiveFunctionAttributes]()
        
        /// Attributes that are defined in a locomotive but not in the global attributes.
        ///
        /// This happens when a locomotive has an unknown attribute to the CS3.
        var unknownAttributes = [UInt32:CommandLocomotiveFunctionAttributes]()
        
        mutating func clear() {
            globalAttributes.removeAll()
            unknownAttributes.removeAll()
        }
    }

    private var attributesCache = AttributesCache()
    private var imageCache = NSCache<NSString, NSImage>()

    private let interface: CommandInterface
    
    /// Returns all the global types defined by the Digital Controller
    var globalTypes: [UInt32] {
        attributesCache.globalAttributes.keys.sorted()
    }
    
    init(interface: CommandInterface) {
        self.interface = interface
    }
    
    func globalAttributesChanged() {
        attributesCache.clear()
        for attributes in interface.defaultLocomotiveFunctionAttributes() {
            add(attributes: attributes)
        }
    }
    
    func add(attributes: CommandLocomotiveFunctionAttributes) {
        if attributesCache.globalAttributes[attributes.type] != nil {
            BTLogger.warning("Duplicate attributes \(attributes.type) for \(attributes.name)")
        }
        attributesCache.globalAttributes[attributes.type] = attributes
    }
    
    func name(for type: UInt32) -> String? {
        return attributesCache.globalAttributes[type]?.name
    }
    
    func image(for type: UInt32, state: Bool) -> NSImage? {
        let funcAttrs = attributes(for: type)

        let svgIconName: String?
        if state {
            svgIconName = funcAttrs.activeSvgIcon
        } else {
            svgIconName = funcAttrs.inactiveSvgIcon
        }
        
        guard let key = svgIconName as? NSString else {
            return nil
        }
        
        if let image = imageCache.object(forKey: key) {
            return image
        }
                
        if let svg = svgIconName, let data = svg.data(using: .utf8), let image = NSImage(data: data)?.copy(size: .init(width: 20, height: 20)) {
            imageCache.setObject(image, forKey: key)
            return image
        } else {
            imageCache.removeObject(forKey: key)
            return nil
        }
    }
    
    private func attributes(for type: UInt32) -> CommandLocomotiveFunctionAttributes {
        if let funcAttrs = attributesCache.globalAttributes[type] {
            return funcAttrs
        } else if let funcAttrs = attributesCache.unknownAttributes[type] {
            return funcAttrs
        } else {
            let funcAttrs = interface.locomotiveFunctionAttributesFor(type: type)
            attributesCache.unknownAttributes[funcAttrs.type] = funcAttrs
            return funcAttrs
        }
    }
    
    func encode() throws -> Data {
        let encoder = JSONEncoder()
        let data = try encoder.encode(attributesCache)
        return data
    }

    func restore(_ data: Data) throws {
        let decoder = JSONDecoder()
        attributesCache = (try? decoder.decode(AttributesCache.self, from: data)) ?? AttributesCache()
    }
}
