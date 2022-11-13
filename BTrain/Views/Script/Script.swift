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

final class Script: Element, ObservableObject {
    let id: Identifier<Script>
    @Published var name: String
    @Published var commands: [ScriptCommand] = []
    
    internal init(uuid: String = UUID().uuidString, name: String = "") {
        self.id = Identifier<Script>(uuid: uuid)
        self.name = name
    }

    internal init(id: Identifier<Script>, name: String = "") {
        self.id = id
        self.name = name
    }

}

extension Script: Codable {
    
    enum CodingKeys: CodingKey {
        case id, name, commands
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(Identifier<Script>.self, forKey: CodingKeys.id)
        let name = try container.decode(String.self, forKey: CodingKeys.name)
        
        self.init(id: id, name: name)
        
        self.commands = try container.decode([ScriptCommand].self, forKey: CodingKeys.commands)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(name, forKey: CodingKeys.name)
        try container.encode(commands, forKey: CodingKeys.commands)
    }
}
