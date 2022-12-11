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
    
    private var type2attributes = [UInt32:CommandLocomotiveFunctionAttributes]()

    private var imageCache = NSCache<NSString, NSImage>()

    var allTypes: [UInt32] {
        type2attributes.keys.sorted()
    }
    
    func process(interface: CommandInterface) {
        type2attributes.removeAll()
        for attributes in interface.locomotiveFunctions() {
            if type2attributes[attributes.type] != nil {
                BTLogger.warning("Duplicate attributes \(attributes.type) for \(attributes.name)")
            }
            type2attributes[attributes.type] = attributes
        }
    }
    
    func name(for type: UInt32) -> String? {
        return type2attributes[type]?.name
    }
    
    func image(for type: UInt32) -> NSImage? {
        let key = String(type) as NSString
        
        if let image = imageCache.object(forKey: key) {
            return image
        }
        
        guard let funcAttrs = type2attributes[type] else {
            return nil
        }
        if let svg = funcAttrs.svgIcon, let data = svg.data(using: .utf8), let image = NSImage(data: data) {
            imageCache.setObject(image, forKey: key)
            return image
        } else {
            imageCache.removeObject(forKey: key)
            return nil
        }
    }
    
    func encode() throws -> Data {
        let encoder = JSONEncoder()
        let data = try encoder.encode(type2attributes)
        return data
    }

    func restore(_ data: Data) throws {
        let decoder = JSONDecoder()
        type2attributes = try decoder.decode([UInt32:CommandLocomotiveFunctionAttributes].self, from: data)
    }
}
