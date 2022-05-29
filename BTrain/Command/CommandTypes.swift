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

// This type defines the speed value express in the unit that the CAN-message
// expects the speed to be provided. This value is specific to each Digital Controller,
// for example for the CS3, the speed value is expected to between 0 and 1000.
struct SpeedValue: Equatable, CustomStringConvertible {
    var value: UInt16
    var description: String {
        "\(value)"
    }
    static let zero = SpeedValue(value: 0)
}

// Define the type of speed when expressed in number of decoder steps
struct SpeedStep: Equatable, Codable, CustomStringConvertible {
    var value: UInt16
    var description: String {
        "\(value) steps"
    }
    static let zero = SpeedStep(value: 0)
}

struct CommandLocomotive {
    let uid: UInt32?
    let name: String?
    let address: UInt32?
    let maxSpeed: UInt32?
    let decoderType: DecoderType
}
