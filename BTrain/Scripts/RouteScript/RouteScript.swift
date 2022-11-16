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

final class RouteScript: Element, ElementCopiable, ObservableObject {
        
    let id: Identifier<RouteScript>
    
    @Published var name: String
    @Published var commands: [RouteScriptCommand] = []
        
    internal convenience init(uuid: String = UUID().uuidString, name: String = "") {
        self.init(id: Identifier<RouteScript>(uuid: uuid), name: name)
    }

    internal init(id: Identifier<RouteScript>, name: String = "") {
        self.id = id
        self.name = name
        self.commands = [.init(action: .start)]
    }

    func copy() -> RouteScript {
        let newScript = RouteScript(name: "\(name) copy")
        newScript.commands = commands
        return newScript
    }

}

extension RouteScript: Codable {
    
    enum CodingKeys: CodingKey {
        case id, name, commands
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(Identifier<RouteScript>.self, forKey: CodingKeys.id)
        let name = try container.decode(String.self, forKey: CodingKeys.name)
        
        self.init(id: id, name: name)
        
        self.commands = try container.decode([RouteScriptCommand].self, forKey: CodingKeys.commands)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(name, forKey: CodingKeys.name)
        try container.encode(commands, forKey: CodingKeys.commands)
    }
}
