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

/// A function to execute during a route
struct RouteItemFunction: Identifiable, Hashable, Equatable, Codable {
    var id = UUID().uuidString

    /// The locomotive associated with this function. This enables locomotive-specific function
    /// to be triggered, for example when more than one function type is available.
    var locomotive: Identifier<Locomotive>?

    /// When a locomotive is specified, this index is used to un-ambiguously indicate the function
    /// number to use with the type.
    ///
    /// This is needed because a type can appears more than once per locomotive
    /// and the index of the function is the only way to differentiate between these two functions.
    /// For example: the Horn function of type 10 appears at index 3 and 7 for the TGV Duplex.
    var locFunction: CommandLocomotiveFunction?

    /// The type of the function. Note that a locomotive can have more than one function
    /// of the same type, like the "Horn" of type 10, which can appears more than once
    /// for a specific locomotive to activate different types of horn sound.
    var type: UInt32

    enum Trigger: Codable {
        case enable
        case disable
        case pulse
    }

    /// The type of function trigger
    var trigger: Trigger = .enable

    /// The duration of the function
    /// - For trigger of type ``enable`` or ``disable``, it represents the delay before the function is triggered.
    /// - For trigger of type ``pulse``, it represents the duration of the pulse.
    @DecodableDefault.Zero var duration: TimeInterval
}

extension RouteItemFunction {
    /// Returns the resolved type of the function
    var resolvedType: UInt32 {
        if let locFunction = locFunction {
            return locFunction.type
        } else {
            return type
        }
    }

    /// Returns the resolved name of the function
    /// - Parameter catalog: the function catalog
    /// - Returns: the name of the function
    func resolvedName(catalog: LocomotiveFunctionsCatalog) -> String {
        if let locFunction = locFunction, let name = catalog.name(for: locFunction.type) {
            return "f\(locFunction.nr): \(name) \(locFunction.type)"
        } else if let name = catalog.name(for: type) {
            return "\(name) \(type)"
        } else {
            return ""
        }
    }
}
