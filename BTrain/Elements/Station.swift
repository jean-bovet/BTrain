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

/// Defines a station which is an element grouping one or more blocks that belong to the same station.
///
/// The station will pick a block given specific behaviors (ie random, round-robin) for the given train.
final class Station: Element, ObservableObject {
    
    let id: Identifier<Station>
    
    var name: String
    
    @Published var elements: [StationElement]
    
    init(id: Identifier<Station>, name: String, elements: [StationElement]) {
        self.id = id
        self.name = name
        self.elements = elements
    }

    func blockFor(train: Train, layout: Layout) -> Block? {
        return layout.block(for: elements.first?.blockId)
    }

    func contains(blockId: Identifier<Block>) -> Bool {
        elements.contains { element in
            element.blockId == blockId
        }
    }
    
    func validBlock(blockId: Identifier<Block>, train: Train, layout: Layout) -> Bool {
        elements.contains { element in
            element.blockId == blockId
        }
    }

    struct StationElement: Identifiable, Codable {
        var id = UUID().uuidString
        var blockId: Identifier<Block>?
        var direction: Direction?
    }
    
}

extension Station: Codable {
    
    enum CodingKeys: CodingKey {
        case id, name, elements
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(Identifier<Station>.self, forKey: CodingKeys.id)
        let name = try container.decode(String.self, forKey: CodingKeys.name)
        let elements = try container.decode([StationElement].self, forKey: CodingKeys.elements)

        self.init(id: id, name: name, elements: elements)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(name, forKey: CodingKeys.name)
        try container.encode(elements, forKey: CodingKeys.elements)
    }
    
}
