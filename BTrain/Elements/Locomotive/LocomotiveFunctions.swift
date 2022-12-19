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

final class LocomotiveFunctions: ObservableObject {
    /// The functions associated with this locomotive
    @Published var definitions = [CommandLocomotiveFunction]() {
        didSet {
            states = definitions.reduce(into: FunctionStates()) { partialResult, function in
                partialResult[function.nr] = function.state
            }
        }
    }

    typealias FunctionStates = [UInt8: UInt8]

    /// Map of state to each function index.
    ///
    /// This map is not persisted because it is re-created each time the connection to the Digital Controller is established.
    @Published var states = FunctionStates()
}

extension LocomotiveFunctions: Codable {
    enum CodingKeys: CodingKey {
        case definitions
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        definitions = try container.decodeIfPresent([CommandLocomotiveFunction].self, forKey: CodingKeys.definitions) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(definitions, forKey: CodingKeys.definitions)
    }
}
