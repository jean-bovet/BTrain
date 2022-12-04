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
import OSLog

/// Manages all the logging happening inside BTrain.
///
/// The underlying implementation uses the unified [OS logging system](https://developer.apple.com/documentation/os/logging).
final class BTLogger {
    enum Category: String {
        case network
        case router
        case speed
        case reservation
    }

    /// Returns a new logger instance
    /// - Parameter category: the category of the logger
    /// - Returns: the logger instance
    private static func newLogger(category: Category) -> Logger {
        isLoggerEnabled(category: category) ? Logger(subsystem: "ch.arizona-software.BTrain", category: category.rawValue) : Logger(OSLog.disabled)
    }

    private static func isLoggerEnabled(category: Category) -> Bool {
        switch category {
        case .network:
            return SettingsKeys.bool(forKey: SettingsKeys.logCategoryNetwork)
        case .router:
            return SettingsKeys.bool(forKey: SettingsKeys.logCategoryRouter)
        case .speed:
            return SettingsKeys.bool(forKey: SettingsKeys.logCategorySpeed)
        case .reservation:
            return SettingsKeys.bool(forKey: SettingsKeys.logCategoryReservation)
        }
    }

    /// The network logger instance
    static var network = newLogger(category: .network)

    /// The router logger instance
    static var router = newLogger(category: .router)

    /// The speed logger instance
    static var speed = newLogger(category: .speed)

    /// The reservation logger instance
    static var reservation = newLogger(category: .reservation)

    /// Re-create the network logger using the latest settings
    static func updateLoggerInstances() {
        network = newLogger(category: .network)
        router = newLogger(category: .router)
        speed = newLogger(category: .speed)
        reservation = newLogger(category: .reservation)
    }

    static func error(_ msg: String) {
        NSLog("⛔️ \(msg)")
    }

    static func debug(_ msg: String) {
        NSLog("\(msg)")
    }

    static func warning(_ msg: String) {
        NSLog("⚠️ \(msg)")
    }
}
