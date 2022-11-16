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

// A feedback is an element that is triggered when
// a train is detected on the train. It is for example
// associated with a reed feedback in the actual layout.
final class Feedback: Element, ObservableObject {
    
    let id: Identifier<Feedback>
        
    @Published var name = ""
    
    @Published var deviceID: UInt16 = 0
    
    @Published var contactID: UInt16 = 0

    @Published var detected = false
    
    init(id: Identifier<Feedback>, deviceID: UInt16 = 0, contactID: UInt16 = 0) {
        self.id = id
        self.name = id.uuid
        self.deviceID = deviceID
        self.contactID = contactID
    }
    
    convenience init(_ uuid: String, deviceID: UInt16 = 0, contactID: UInt16 = 0) {
        self.init(id: Identifier(uuid: uuid), deviceID: deviceID, contactID: contactID)
    }

}

extension Feedback: Codable {
    
    enum CodingKeys: CodingKey {
      case id, name, deviceID, contactID
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try container.decode(Identifier<Feedback>.self, forKey: CodingKeys.id))
        self.name = try container.decode(String.self, forKey: CodingKeys.name)
        self.deviceID = try container.decode(UInt16.self, forKey: CodingKeys.deviceID)
        self.contactID = try container.decode(UInt16.self, forKey: CodingKeys.contactID)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)
        try container.encode(name, forKey: CodingKeys.name)
        try container.encode(deviceID, forKey: CodingKeys.deviceID)
        try container.encode(contactID, forKey: CodingKeys.contactID)
    }

}

extension Array where Element : Feedback {

    func find(deviceID: UInt16, contactID: UInt16) -> Element? {
        self.first { feedback in
            feedback.deviceID == deviceID && feedback.contactID == contactID
        }
    }
    
}
