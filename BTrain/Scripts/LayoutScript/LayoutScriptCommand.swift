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

struct LayoutScriptCommand: ScriptCommand, Identifiable, Hashable {
    
    let id: UUID
    
    enum Action: String, CaseIterable, Codable {
        // Run train "S-Bahn" with route "Outer Loop"
        case run = "Run"
    }

    var action: Action = .run
    
    var children = [LayoutScriptCommand]()
    
    var train: Identifier<Train>?
    var route: Identifier<RouteScript>?
    
    init(id: UUID = UUID(), action: Action) {
        self.id = id
        self.action = action
    }
}

extension LayoutScriptCommand: Codable {
    
    enum CodingKeys: CodingKey {
        case id, action, children, train, route
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: CodingKeys.id)
        self.action = try container.decode(Action.self, forKey: CodingKeys.action)
        self.children = try container.decode([LayoutScriptCommand].self, forKey: CodingKeys.children)
        
        self.train = try container.decode(Identifier<Train>.self, forKey: CodingKeys.train)
        self.route = try container.decode(Identifier<RouteScript>.self, forKey: CodingKeys.route)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(action, forKey: CodingKeys.action)
        try container.encode(children, forKey: CodingKeys.children)
        try container.encode(train, forKey: CodingKeys.train)
        try container.encode(route, forKey: CodingKeys.route)
    }
}
